# frozen_string_literal: true

require 'adwaita'
require_relative 'file'
require_relative 'ui_utilities'

module Nautilus
  # MimeActions opens files: a folder in the view, anything else in the app
  # that handles it, with the prompts that go with the awkward cases.
  #
  # Ported from src/nautilus-mime-actions.c. The five alert dialogs are
  # upstream's — the broken link, the "open all these" confirmation, the
  # missing handler with its Select App response, the Software search offer,
  # and the untrusted launcher — along with the three "Unable to …" alerts
  # reported for a location that will not open, start or mount.
  module MimeActions
    # How many files may be opened at once before the confirmation appears.
    SILENT_OPEN_LIMIT = 5

    module_function

    # nautilus_mime_activate_files(): folders are opened in the view, the
    # rest are handed to their handler, and a long selection is confirmed
    # first.
    def activate_files(files, parent:, on_open_location:, on_open_in_new_tab: nil)
      files.partition(&:directory?).then do |(folders, documents)|
        if (folders.size + documents.size) > SILENT_OPEN_LIMIT
          confirm_open_all(
            folders,
            documents,
            parent,
            on_open_location,
            on_open_in_new_tab,
          )
        else
          open_all(
            folders,
            documents,
            parent,
            on_open_location,
            on_open_in_new_tab,
          )
        end
      end
    end

    def activate_file(file, parent:, on_open_location:)
      activate_files([file], parent: parent, on_open_location: on_open_location)
    end

    # nautilus_mime_file_opens_in_view(): what the view itself shows rather
    # than handing to another app.
    def opens_in_view?(file) = file.directory?

    def open_all(folders, documents, parent, on_open_location, on_open_in_new_tab)
      folders.each_with_index do |folder, index|
        if index.zero?
          on_open_location.call(folder.location)
        else
          (on_open_in_new_tab || on_open_location).call(folder.location)
        end
      end
      documents.each { |document| launch(document, parent) }
    end

    # activate_files_internal()'s confirmation when the selection would open
    # more than a handful of tabs and windows.
    def confirm_open_all(folders, documents, parent, on_open_location, on_open_in_new_tab)
      Adwaita::AlertDialog.new(
        'Are you sure you want to open all files?',
        open_all_detail(folders.size + documents.size),
      ).tap do |dialog|
        dialog.add_response('cancel', '_Cancel')
        dialog.add_response('open-all', '_Open All')
        dialog.default_response = 'open-all'
        dialog.close_response = 'cancel'
        dialog.signal_connect('response') do |_dialog, response|
          if response == 'open-all'
            open_all(
              folders,
              documents,
              parent,
              on_open_location,
              on_open_in_new_tab,
            )
          end
        end
        dialog.present(parent)
      end
    end

    def open_all_detail(count)
      if count == 1
        'This will open 1 separate tab.'
      else
        "This will open #{count} separate tabs."
      end
    end

    # A broken symlink is offered for trashing rather than opened.
    def report_broken_link(file, parent, &on_trash)
      Adwaita::AlertDialog.new(nil, "This link cannot be used because its target “#{file.symlink_target}” doesn't exist.").tap do |dialog|
        dialog.heading = broken_link_heading(file)
        dialog.add_response('cancel', '_Cancel')
        if file.can_trash?
          dialog.add_response('move-to-trash', 'Mo_ve to Trash')
        end
        dialog.default_response = 'cancel'
        dialog.close_response = 'cancel'
        dialog.signal_connect('response') do |_dialog, response|
          if response == 'move-to-trash'
            on_trash.call(file)
          end
        end
        dialog.present(parent)
      end
    end

    def broken_link_heading(file)
      if file.can_trash?
        "The link “#{file.display_name}” is broken. Move it to Trash?"
      else
        "The link “#{file.display_name}” is broken."
      end
    end

    # application_cannot_open_location(): nothing is installed for this type,
    # so the user is offered the app chooser or Software.
    def report_no_handler(file, parent, &on_select_app)
      Adwaita::AlertDialog.new(
        no_handler_message(file),
        "There is no app installed for “#{Nautilus::File.description_for(file.content_type)}” files",
      ).tap do |dialog|
        dialog.add_response('select-application', '_Select App')
        dialog.add_response('ok', '_OK')
        dialog.default_response = 'ok'
        dialog.close_response = 'ok'
        dialog.signal_connect('response') do |_dialog, response|
          if response == 'select-application'
            on_select_app&.call(file)
          end
        end
        dialog.present(parent)
      end
    end

    def no_handler_message(file)
      "Could not display “#{file.display_name}”."
    end

    # show_dialog_prompting_install(): the Software offer.
    def offer_software_search(file, parent, &on_search)
      Adwaita::AlertDialog.new(
        no_handler_message(file),
        "There is no app installed for “#{Nautilus::File.description_for(file.content_type)}” files. " \
          'Do you want to search for an app to open this file?',
      ).tap do |dialog|
        dialog.add_response('cancel', '_Cancel')
        dialog.add_response('search-in-software', '_Search in Software')
        dialog.default_response = 'search-in-software'
        dialog.close_response = 'cancel'
        dialog.signal_connect('response') do |_dialog, response|
          if response == 'search-in-software'
            on_search&.call(file)
          end
        end
        dialog.present(parent)
      end
    end

    # An executable or .desktop file the user has not marked trusted is not
    # run on a double click.
    def report_untrusted_launcher(file, parent, &on_trust)
      Adwaita::AlertDialog.new(
        'Untrusted application launcher',
        "The application launcher “#{file.display_name}” has not been marked as trusted. " \
          'If you do not know the source of this file, launching it may be unsafe.',
      ).tap do |dialog|
        dialog.add_response('cancel', '_Cancel')
        dialog.add_response('trust', 'Trust and _Launch')
        dialog.default_response = 'cancel'
        dialog.close_response = 'cancel'
        dialog.signal_connect('response') do |_dialog, response|
          if response == 'trust'
            on_trust&.call(file)
          end
        end
        dialog.present(parent)
      end
    end

    def report_unable_to_access_location(error, parent)
      UiUtilities.show_ok_dialog('Unable to access location', error.message, parent)
    end

    def report_unable_to_start_location(error, parent)
      UiUtilities.show_ok_dialog('Unable to start location', error.message, parent)
    end

    # nautilus_mime_activate_file(): hands the file to its default handler.
    def launch(file, parent)
      if file.symlink? && file.symlink_target && !::File.exist?(expanded_target(file))
        report_broken_link(file, parent) { |broken| broken.location.trash }
      elsif default_app_for(file).nil?
        report_no_handler(file, parent)
      else
        launch_with(file, parent)
      end
    end

    def expanded_target(file)
      ::File.expand_path(file.symlink_target, ::File.dirname(file.path.to_s))
    end

    def default_app_for(file)
      Gio::AppInfo.get_default_for_type(file.content_type, false)
    rescue GLib::Error
      nil
    end

    # Gtk::FileLauncher is what upstream uses, so the portal is honoured and
    # the app is launched on the user's behalf rather than as a child of this
    # process.
    def launch_with(file, parent)
      Gtk::FileLauncher.new(file.location).launch(parent, nil)
    rescue GLib::Error => error
      report_unable_to_access_location(error, parent)
    end

    # The apps offered by the Open With submenu.
    def apps_for(file)
      Gio::AppInfo.get_all_for_type(file.content_type)
    rescue GLib::Error
      []
    end
  end
end
