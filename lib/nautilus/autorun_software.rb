# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # AutorunSoftware confirms and runs a mount's autorun program.
  #
  # Ported from src/nautilus-autorun-software.c: the trust prompt built with
  # an AdwAlertDialog, the ".autorun"/"autorun"/"autorun.sh" lookup order
  # (the first two must be executable, the shell script does not need to
  # be), and the "Unable to locate the program" / "not marked as
  # executable" error alert when nothing could be run. The upstream file is
  # a standalone helper binary invoked by nautilus with a mount URI; this
  # port exposes the same behavior as a class the window can call directly
  # with a Gio::Mount.
  class AutorunSoftware
    def initialize(mount, on_closed: nil)
      @mount = mount
      @unmounted_handler = nil
      @on_closed = on_closed
    end

    def present(parent)
      watch_unmount
      dialog.signal_connect('closed') { @on_closed&.call }
      dialog.present(parent)
    end

    private

      def dialog
        @dialog ||= Adwaita::AlertDialog.new(nil, "If you don’t trust this location or aren’t sure, press Cancel.").tap do |alert|
          # adw_alert_dialog_format_heading() (a printf-style formatter) has
          # no binding in this adwaita gem build — only the plain `heading`
          # property setter does — so the mount name is interpolated here in
          # Ruby first, same as the C call's own %s substitution would do.
          alert.heading = "“%s” contains software intended to be automatically started. Would you like to run it?" % mount_name
          alert.add_response('cancel', '_Cancel')
          alert.add_response('run', '_Run')
          alert.default_response = 'cancel'
          alert.close_response = 'cancel'
          alert.signal_connect('response') { |_dialog, response| on_response(response) }
        end
      end

      def mount_name = @mount.name

      def on_response(response)
        if response == 'run'
          run
        end
      end

      # The mount going away while the dialog is still up (media ejected,
      # device unplugged) closes it, matching
      # autorun_software_dialog_mount_unmounted().
      def watch_unmount
        @unmounted_handler = @mount.signal_connect('unmounted') { close_dialog }
      end

      def close_dialog
        unless dialog.destroyed?
          dialog.force_close
        end
      end

      # autorun(): try the three candidates in upstream's order and report
      # why nothing ran when none of them worked.
      def run
        candidate = pick_candidate(@mount.root)
        if candidate
          spawn_candidate(candidate)
        else
          report_error('Unable to locate the program')
        end
      end

      # Careful here, according to the autostart spec the ordering matters:
      # an executable ".autorun" wins, then an executable "autorun", then
      # "autorun.sh" run through /bin/sh (which does not need to be
      # executable itself).
      def pick_candidate(root)
        [
          executable_candidate(root, '.autorun'),
          executable_candidate(root, 'autorun'),
          shell_candidate(root, 'autorun.sh'),
        ].find { |candidate| candidate[:runnable] }
      end

      def executable_candidate(root, name)
        file = root.get_child(name)
        {file: file, argument_file: nil, runnable: executable?(file)}
      end

      def shell_candidate(root, name)
        file = root.get_child(name)
        {file: Gio::File.new_for_path('/bin/sh'), argument_file: file, runnable: exists?(file)}
      end

      def executable?(file)
        access_info(file)&.get_attribute_boolean('access::can-execute') == true
      end

      def exists?(file) = !access_info(file).nil?

      def access_info(file)
        file.query_info('access::can-execute', Gio::FileQueryInfoFlags::NONE, nil)
      rescue GLib::ErrorInfo
        nil
      end

      def spawn_candidate(candidate)
        path = candidate[:file].path
        argument_file = candidate[:argument_file]
        cwd = (argument_file || candidate[:file]).parent.path
        argv = argument_file ? [path, argument_file.path] : [path]
        Gio::SubprocessLauncher.new(Gio::SubprocessFlags::NONE).tap do |launcher|
          launcher.cwd = cwd
          launcher.spawnv(argv)
        end
      rescue GLib::ErrorInfo => e
        report_error("Unable to start the program:\n%s" % e.message)
      end

      def report_error(message)
        Adwaita::AlertDialog.new('Oops! There was a problem running this software.', message).tap do |alert|
          alert.add_response('ok', '_OK')
          alert.default_response = 'ok'
          alert.present(nil)
        end
      end
  end
end
