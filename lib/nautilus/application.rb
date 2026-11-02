# frozen_string_literal: true

require 'gtk4'
require 'adwaita'
require_relative 'style'
require_relative 'global_preferences'
require_relative 'date_utilities'
require_relative 'window'
require_relative 'shortcuts_dialog'
require_relative 'preferences_dialog'
require_relative 'dbus_launcher'

module Nautilus
  # Application owns the app actions, the accelerators and the windows.
  #
  # Ported from src/nautilus-application.c: the eight `app.*` actions, their
  # accelerators, the About dialog built in code, and one window per
  # activation. The stylesheet and the date preferences are set up on
  # startup, which is where nautilus_application_startup() does it too.
  class Application
    APPLICATION_ID = 'org.rubygtkproject.Nautilus'

    # The accelerators nautilus_application_startup() installs.
    ACCELERATORS = {
      'app.clone-window'                 => ['<Primary>n'],
      'app.preferences'                  => ['<Primary>comma'],
      'app.quit'                         => ['<Primary>q'],
      'win.new-tab'                      => ['<Primary>t'],
      'win.close-current-view'           => ['<Primary>w'],
      'win.open-tab-overview'            => ['<Primary><Shift>o'],
      'win.restore-tab'                  => ['<Primary><Shift>t'],
      'win.go-home'                      => ['<alt>Home'],
      'win.toggle-sidebar'               => ['F9'],
      'slot.back'                        => ['<alt>Left'],
      'slot.forward'                     => ['<alt>Right'],
      'slot.up'                          => ['<alt>Up'],
      'slot.down'                        => ['<alt>Down'],
      'slot.reload'                      => ['F5', '<Primary>r'],
      'view.new-folder'                  => ['<Primary><Shift>n'],
      'view.select-all'                  => ['<Primary>a'],
      'view.invert-selection'            => ['<Primary><Shift>i'],
      'view.select-pattern'              => ['<Primary>s'],
      'view.rename'                      => ['F2'],
      'view.cut'                         => ['<Primary>x'],
      'view.copy'                        => ['<Primary>c'],
      'view.paste'                       => ['<Primary>v'],
      'view.move-to-trash'               => ['Delete'],
      'view.delete-permanently-shortcut' => ['<Shift>Delete'],
      'view.show-hidden-files'           => ['<Primary>h'],
      'view.zoom-in'                     => ['<Primary>plus', '<Primary>equal'],
      'view.zoom-out'                    => ['<Primary>minus'],
      'view.zoom-standard'               => ['<Primary>0'],
    }.freeze

    def build
      app.tap do
        app.signal_connect('startup') { on_startup }
        app.signal_connect('activate') { on_activate }
        app.signal_connect('open') { |_app, files, _hint| on_open(files) }
      end
    end

    def run(argv = ARGV) = app.run(argv)

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the windows are Adwaita.
    def app
      @app ||= Gtk::Application.new(APPLICATION_ID, [:handles_open, :default_flags])
    end

    def windows = @windows ||= []

    private

      def on_startup
        Adwaita.init
        Style.install
        DateUtilities.setup_preferences
        install_actions
        install_accelerators
      end

      def on_activate
        open_window(nil)
      end

      # The `open` signal carries the locations named on the command line.
      def on_open(files)
        Array(files).each { |location| open_window(location) }
      end

      def open_window(location)
        Window.new(app, location: location, on_new_window: ->(target) { open_window(target) })
              .tap do |window|
          windows << window
          window.build
          window.present
        end
      end

      def install_actions
        action_handlers.each do |name, handler|
          app.add_action(
            Gio::SimpleAction.new(name).tap do |action|
                        action.signal_connect('activate') { handler.call }
                      end,
          )
        end
      end

      def action_handlers
        {
          'new-window'      => -> { open_window(nil) },
          'clone-window'    => -> { clone_window },
          'preferences'     => -> { show_preferences },
          'search-settings' => -> { DBusLauncher.instance.open_settings_panel('search') },
          'about'           => -> { show_about },
          'help'            => -> { show_help },
          'shortcuts'       => -> { show_shortcuts },
          'quit'            => -> { quit },
          'kill'            => -> { app.quit },
        }
      end

      def install_accelerators
        ACCELERATORS.each do |action, accelerators|
          app.set_accels_for_action(action, accelerators)
        end
      end

      # app.clone-window opens a window on the same location as the active
      # one, where app.new-window starts at home.
      def clone_window
        open_window(windows.last&.active_slot&.location)
      end

      def show_preferences
        PreferencesDialog.new.tap do |dialog|
          dialog.build
          dialog.present(active_window)
        end
      end

      def show_shortcuts
        ShortcutsDialog.new.build.present(active_window)
      end

      def show_help
        Gtk::UriLauncher.new('help:gnome-help/files').launch(active_window, nil)
      rescue GLib::Error
        nil
      end

      def show_about
        Adwaita::AboutDialog.new.tap do |dialog|
          dialog.application_name = 'Files'
          dialog.application_icon = 'system-file-manager'
          dialog.developer_name = 'The Files contributors'
          dialog.license_type = Gtk::License::GPL_3_0
          dialog.website = 'https://apps.gnome.org/Nautilus'
          dialog.issue_url = 'https://gitlab.gnome.org/GNOME/nautilus/-/issues'
          dialog.comments = 'A Ruby GTK4 / Libadwaita port of GNOME Files.'
          dialog.present(active_window)
        end
      end

      # The geometry is recorded before the windows go, which is what
      # nautilus_application_shutdown() does.
      def quit
        windows.each { |window| GlobalPreferences.instance.remember(window.window) }
        app.quit
      end

      def active_window = app.active_window
  end
end
