# frozen_string_literal: true

require 'adwaita'
require 'ashpd'
require 'gnome-autoar'
require_relative 'dialog_utilities'
require_relative 'ui_utilities'
require_relative 'file_conflict_dialog'
require_relative 'file'

module Nautilus
  # FileOperations copies, moves, trashes, deletes and links files, and asks
  # the questions that go with those.
  #
  # Ported from src/nautilus-file-operations.c. The confirmation wording,
  # which responses each prompt offers and which of them is destructive are
  # upstream's; the error reporting goes through the same "Error while
  # copying to “%s”." / "Error while moving." headings. Upstream runs each
  # operation as a cancellable job on a worker thread reporting into the
  # progress manager; here each operation is a GIO call chain made from the
  # main loop, reporting through the `on_done` callback the caller passes.
  module FileOperations
    module_function

    # nautilus_file_operations_copy_move(): copying into a folder, or moving
    # into it when `move` is set. Each location is transferred in turn; a
    # name conflict pauses the sequence on FileConflictDialog (#transfer's
    # continuation), rather than transferring the rest while that question
    # is still on screen.
    def copy_move(locations, destination, move: false, parent: nil, &on_done)
      apply_to_all = { response: nil }
      transfer_each(locations.dup, destination, move, parent, apply_to_all, on_done)
    end

    def transfer_each(remaining, destination, move, parent, apply_to_all, on_done)
      if remaining.empty?
        on_done&.call(destination)
      else
        location = remaining.shift
        target = destination.get_child(location.basename)
        transfer(location, target, move, parent, apply_to_all) do
          transfer_each(remaining, destination, move, parent, apply_to_all, on_done)
        end
      end
    end

    def copy(locations, destination, parent: nil, &on_done)
      copy_move(
        locations,
        destination,
        move: false, parent: parent,
        &on_done
      )
    end

    def move(locations, destination, parent: nil, &on_done)
      copy_move(
        locations,
        destination,
        move: true, parent: parent,
        &on_done
      )
    end

    # nautilus_file_operations_trash_or_delete_sync(): trashing needs no
    # confirmation, since it can be undone.
    #
    # Upstream reaches the real trash through GIO's g_file_trash(), which
    # already goes through the Trash portal when sandboxed (gvfs calls the
    # same D-Bus interface Ashpd::Trash wraps). This port tries the portal
    # call first so it works the way a Flatpak build of this app would, and
    # falls back to the direct GIO call for the common case of a portal-less
    # session (no xdg-desktop-portal running, e.g. this dev shell) or an
    # unsandboxed desktop where GIO's own trash implementation is enough.
    def trash(locations, parent: nil, &on_done)
      locations.each do |location|
        begin
          trash_one(location)
        rescue GLib::Error, GLib::ErrorInfo => error
          report_trash_error(location, error, parent)
        end
      end
      on_done&.call(locations)
    end

    def trash_one(location)
      path = location.path
      if path
        Ashpd::Trash.file(path)
      else
        location.trash
      end
    rescue RuntimeError
      # The portal call failed (no xdg-desktop-portal, or it refused the
      # request) — GIO's own trash implementation still works outside a
      # sandbox, so fall back to it rather than surfacing a portal-specific
      # error for a feature that still works the ordinary way.
      location.trash
    end

    # nautilus_file_operations_delete(): deleting for good is confirmed
    # first, with the count-aware wording of confirm_delete_directly().
    def delete(locations, parent: nil, &on_done)
      confirm_delete(locations, parent) do
        locations.each { |location| delete_recursively(location) }
        on_done&.call(locations)
      end
    end

    # nautilus_file_operations_empty_trash().
    def empty_trash(parent: nil, &on_done)
      DialogUtilities.dialog_with_responses(
        'Empty Trash?',
        'All items in the Trash will be permanently deleted',
        responses: [DialogUtilities::EMPTY_TRASH],
      ).tap do |dialog|
        dialog.signal_connect('response') do |_dialog, response|
          if response == DialogUtilities::EMPTY_TRASH
            delete_trash_contents
            on_done&.call
          end
        end
        dialog.present(parent)
      end
    end

    # nautilus_file_operations_link().
    def create_links(locations, destination, parent: nil, &on_done)
      locations.each do |location|
        destination.get_child("Link to #{location.basename}").then do |target|
          make_symlink(location, target, parent)
        end
      end
      on_done&.call(destination)
    end

    # nautilus_file_operations_new_folder().
    def new_folder(parent_location, name, parent: nil)
      parent_location.get_child(name).tap do |target|
        target.make_directory
      end
    rescue GLib::Error => error
      UiUtilities.show_ok_dialog(
        "Error while creating directory “#{name}”.",
        error.message,
        parent,
      )
      nil
    end

    # nautilus_file_operations_new_file().
    def new_file(parent_location, name, parent: nil)
      parent_location.get_child(name).tap do |target|
        target.create(:none).close
      end
    rescue GLib::Error => error
      UiUtilities.show_ok_dialog(
        "Error while creating file “#{name}”.",
        error.message,
        parent,
      )
      nil
    end

    def rename(location, new_name)
      location.set_display_name(new_name)
    end

    # nautilus_file_operations_extract_files(): extract each archive beside
    # itself (extract-here) or into `destination` when one is given
    # (extract-to). GnomeAutoar::Extractor does the actual decompression; it
    # supports every format libarchive does, which is why upstream uses it
    # rather than shelling out to `tar`/`unzip`.
    #
    # Both the C source and this port hand Extractor a *parent* directory,
    # never the final extracted folder: with `output_is_dest` left at its
    # default (false), the extractor itself invents the suggested
    # destination name (from the archive's own basename, de-duplicated
    # against what is already there) inside whatever directory it is given,
    # exactly as extract_task_thread_func() does in
    # src/nautilus-file-operations.c, which always passes its
    # destination_directory straight to autoar_extractor_new() with no
    # pre-computed subfolder of its own.
    #
    # An earlier version of this method pre-computed that subfolder itself
    # (stripping the archive's extension) and then handed autoar that
    # *already-final* folder as the parent directory too — autoar dutifully
    # invented its own suggested name inside it, so "photos.tar.gz" landed
    # at "photos/photos/…" instead of "photos/…". Confirmed with a real
    # tar.gz and a signal_connect on "completed": the double nesting shows
    # up on disk, not just in theory.
    def extract(locations, destination: nil, parent: nil, &on_done)
      locations.each do |location|
        target = destination || location.parent
        begin
          GnomeAutoar::Extractor.new(location, target).start(nil)
        rescue GLib::Error, RuntimeError => error
          UiUtilities.show_ok_dialog(
            "Error while extracting “#{location.basename}”.",
            error.message,
            parent,
          )
        end
      end
      on_done&.call(destination)
    end

    # view.compress is NOT wired to GnomeAutoar::Compressor: its `format`
    # and `filter` constructor parameters are GnomeAutoar::Format /
    # GnomeAutoar::Format::Filter, plain C enums with no glib:get-type in
    # GnomeAutoar-0.1.gir, the same "not a registered GType" problem
    # DesktopThumbnailSize has (see Image#thumbnail_path). Every value
    # tried against them — the enum constant, an Integer, a Symbol, a
    # String, nil — is rejected by gobject-introspection's Ruby loader as
    # "interface(NilClass(void))", so no AutoarCompressor can be
    # constructed through this gem. GnomeAutoar::Extractor has no enum
    # parameters and works (see #extract above); only Compressor is
    # affected.

    # --- The prompts --------------------------------------------------------

    # confirm_delete_directly() and confirm_delete_from_trash() share their
    # wording; the count decides which of the two forms is used.
    def confirm_delete(locations, parent)
      DialogUtilities.dialog_with_responses(
        delete_prompt(locations),
        'Permanently deleted items can not be restored',
        responses: [DialogUtilities::DELETE],
      ).tap do |dialog|
        dialog.signal_connect('response') do |_dialog, response|
          if response == DialogUtilities::DELETE
            yield
          end
        end
        dialog.present(parent)
      end
    end

    def delete_prompt(locations)
      if locations.size == 1
        "Permanently Delete “#{locations.first.basename}”?"
      else
        "Permanently Delete #{locations.size} Selected Items?"
      end
    end

    # --- The work -----------------------------------------------------------

    # Transfers one top-level location, then calls `continue`. A name
    # already taken at the destination (G_IO_ERROR_EXISTS) is not reported
    # as a plain error: it pauses on FileConflictDialog so the user can
    # replace, rename or skip, matching nautilus-operations-ui-manager.c's
    # role for the single-file case. `apply_to_all` remembers a choice the
    # user already made "for all" so later conflicts in the same transfer
    # skip the dialog and repeat it.
    def transfer(location, target, move, parent, apply_to_all, &continue)
      if apply_to_all[:response] == DialogUtilities::SKIP_ALL
        continue.call
      else
        replace = apply_to_all[:response] == DialogUtilities::REPLACE
        if move
          location.move(target, replace ? :overwrite : :nofollow_symlinks)
        else
          copy_recursively(location, target, force_replace: replace)
        end
        continue.call
      end
    rescue Gio::IOError::Exists
      resolve_conflict(location, target, move, parent, apply_to_all, &continue)
    rescue GLib::Error => error
      report_transfer_error(
        target,
        error,
        move,
        parent,
      )
      continue.call
    end

    def resolve_conflict(location, target, move, parent, apply_to_all, &continue)
      source_file = File.for_location(location)
      dest_file = File.for_location(target)

      FileConflictDialog.new(parent: parent).tap do |dialog|
        dialog.build
        dialog.set_text(
          "A file named “#{target.basename}” already exists. Do you want to replace it?",
          "The file already exists in “#{target.parent&.basename}”. Replacing it will overwrite its content.",
        )
        dialog.set_images(dest_file, source_file)
        dialog.set_file_labels(dest_file.display_name, source_file.display_name)
        dialog.suggested_name = unique_name_for(target)
        dialog.conflict_name = target.basename

        dialog.dialog.signal_connect('close-request') do
          on_conflict_response(dialog.response, dialog, location, target, move, parent, apply_to_all, &continue)
          false
        end
        dialog.present
      end
    end

    def on_conflict_response(response, dialog, location, target, move, parent, apply_to_all, &continue)
      case response
      when FileConflictDialog::RESPONSE_REPLACE
        if dialog.apply_to_all?
          apply_to_all[:response] = DialogUtilities::REPLACE
        end
        transfer(location, target, move, parent, { response: DialogUtilities::REPLACE }, &continue)
      when FileConflictDialog::RESPONSE_RENAME
        new_target = target.parent.get_child(dialog.new_name)
        transfer(location, new_target, move, parent, apply_to_all, &continue)
      when FileConflictDialog::RESPONSE_SKIP
        if dialog.apply_to_all?
          apply_to_all[:response] = DialogUtilities::SKIP_ALL
        end
        continue.call
      else
        continue.call
      end
    end

    # nautilus_file_operations_get_target_file(): the "(1)" suggestion a
    # conflicting name gets offered as a rename.
    def unique_name_for(target)
      basename = target.basename
      extension = basename.rindex('.').then { |dot| dot && dot.positive? ? basename[dot..] : '' }
      stem = extension.empty? ? basename : basename[0...-extension.length]
      count = 1
      candidate = target
      while candidate.query_exists(nil)
        candidate = target.parent.get_child("#{stem} (#{count})#{extension}")
        count += 1
      end
      candidate.basename
    end

    # g_file_copy() does not recurse into folders, so a folder is recreated
    # at the target and its children copied one by one. `force_replace`
    # is set once the conflict dialog's Replace response has resolved the
    # top-level conflict; it is passed back through #transfer so the
    # overwrite is actually performed.
    def copy_recursively(location, target, force_replace: false)
      if location.query_file_type(:none, nil) == :directory
        copy_directory(location, target, force_replace: force_replace)
      else
        location.copy(target, force_replace ? :overwrite : :none)
      end
    end

    def copy_directory(location, target, force_replace: false)
      make_directory_unless_present(target)
      children_of(location).each do |child|
        copy_recursively(child, target.get_child(child.basename), force_replace: force_replace)
      end
    end

    def delete_recursively(location)
      if location.query_file_type(:none, nil) == :directory
        children_of(location).each { |child| delete_recursively(child) }
      end
      location.delete
    rescue GLib::Error
      nil
    end

    def delete_trash_contents
      children_of(Gio::File.new_for_uri('trash:///')).each do |child|
        delete_recursively(child)
      end
    rescue GLib::Error
      nil
    end

    # GLocalFileEnumerator is not enumerable in the Ruby bindings; the only
    # way through it is next_file() until it returns nil.
    def children_of(location)
      location.enumerate_children('standard::name', :nofollow_symlinks, nil).then do |enumerator|
        children = []
        while (info = enumerator.next_file(nil))
          children << enumerator.get_child(info)
        end
        enumerator.close
        children
      end
    rescue GLib::Error
      []
    end

    def make_directory_unless_present(target)
      target.make_directory
    rescue Gio::IOError::Exists
      nil
    end

    def make_symlink(location, target, parent)
      target.make_symbolic_link(location.path)
    rescue GLib::Error => error
      UiUtilities.show_ok_dialog(
        "Error while creating link to “#{location.basename}”.",
        error.message,
        parent,
      )
    end

    def report_transfer_error(target, error, move, parent)
      if move
        UiUtilities.show_ok_dialog('Error while moving.', error.message, parent)
      else
        UiUtilities.show_ok_dialog(
          "Error while copying to “#{target.parent&.basename}”.",
          error.message,
          parent,
        )
      end
    end

    def report_trash_error(location, error, parent)
      UiUtilities.show_ok_dialog(
        "Unable to move “#{location.basename}” to the Trash.",
        error.message,
        parent,
      )
    end
  end
end
