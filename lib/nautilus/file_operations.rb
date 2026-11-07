# frozen_string_literal: true

require 'adwaita'
require 'ashpd'
require 'gnome-autoar'
require_relative 'dialog_utilities'
require_relative 'ui_utilities'

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
    # into it when `move` is set.
    def copy_move(locations, destination, move: false, parent: nil, &on_done)
      locations.each do |location|
        target = destination.get_child(location.basename)
        transfer(
          location,
          target,
          move,
          parent,
        )
      end
      on_done&.call(destination)
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

    # nautilus_file_operations_extract_files(): extract each archive into a
    # sibling folder named after it (extract-here) or into `destination`
    # when one is given (extract-to). GnomeAutoar::Extractor does the actual
    # decompression; it supports every format libarchive does, which is why
    # upstream uses it rather than shelling out to `tar`/`unzip`.
    def extract(locations, destination: nil, parent: nil, &on_done)
      locations.each do |location|
        target = destination || extract_here_target(location)
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

    # Extract-here's target is a folder beside the archive, named after it
    # with its extension stripped — e.g. "photos.tar.gz" extracts into
    # "photos" next to it, matching autoarchive's own suggested-name logic.
    def extract_here_target(location)
      name = location.basename.sub(/\.(tar\.(gz|bz2|xz)|tgz|zip|7z|rar|gz|bz2|xz)\z/i, '')
      location.parent.get_child(name)
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

    def transfer(location, target, move, parent)
      if move
        location.move(target, :nofollow_symlinks)
      else
        copy_recursively(location, target)
      end
    rescue GLib::Error => error
      report_transfer_error(
        target,
        error,
        move,
        parent,
      )
    end

    # g_file_copy() does not recurse into folders, so a folder is recreated
    # at the target and its children copied one by one.
    def copy_recursively(location, target)
      if location.query_file_type(:none, nil) == :directory
        copy_directory(location, target)
      else
        location.copy(target, :none)
      end
    end

    def copy_directory(location, target)
      make_directory_unless_present(target)
      children_of(location).each do |child|
        copy_recursively(child, target.get_child(child.basename))
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
