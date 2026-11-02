# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # DBusLauncher starts Settings, Disks and Console over D-Bus.
  #
  # Ported from src/nautilus-dbus-launcher.c: the three apps upstream reaches
  # this way, each with the bus name, object path and interface it declares,
  # and an availability check so the menu items that use them are hidden when
  # the app is not installed. Availability is asked of the session bus's
  # ListActivatableNames, which is what upstream watches too.
  class DBusLauncher
    APPS = {
      settings: {
        name:      'org.gnome.Settings',
        path:      '/org/gnome/Settings',
        interface: 'org.gtk.Actions',
      },
      disks:    {
        name:      'org.gnome.DiskUtility',
        path:      '/org/gnome/DiskUtility',
        interface: 'org.gtk.Application',
      },
      console:  {
        name:      'org.gnome.Console',
        path:      '/org/gnome/Console',
        interface: 'org.freedesktop.Application',
      },
    }.freeze

    def self.instance = @instance ||= new

    def available?(app)
      activatable_names.include?(APPS.fetch(app).fetch(:name))
    end

    # nautilus_dbus_launcher_call(): fire the method and forget it; a failure
    # to launch is not worth a dialog, which is what upstream does too.
    def call(app, method_name, parameters)
      APPS.fetch(app).then do |details|
        connection&.call(
          details.fetch(:name),
          details.fetch(:path),
          details.fetch(:interface),
          method_name,
          parameters,
          nil,
          :none,
          -1,
          nil,
        )
      end
      true
    rescue GLib::Error
      false
    end

    # The platform data every org.gtk/org.freedesktop launch method takes as
    # its last argument.
    def platform_data = GLib::Variant.parse('@a{sv} {}')

    def open_console(uri)
      call(
        :console,
        'Open',
        GLib::Variant.parse(%(@(asa{sv}) ([#{uri.to_s.inspect}], {}))),
      )
    end

    def open_disks
      call(:disks, 'Activate', GLib::Variant.parse('@(a{sv}) ({},)'))
    end

    def open_settings_panel(panel)
      call(
        :settings,
        'Activate',
        GLib::Variant.parse(%(@(savaa{sv}) ("launch-panel", [<("#{panel}", @av [])>], {}))),
      )
    end

    private

      def connection
        @connection ||= Gio.bus_get_sync(:session, nil)
      rescue GLib::Error
        nil
      end

      def activatable_names
        @activatable_names ||= read_activatable_names
      end

      def read_activatable_names
        connection&.call_sync(
          'org.freedesktop.DBus',
          '/org/freedesktop/DBus',
          'org.freedesktop.DBus',
          'ListActivatableNames',
          nil,
          nil,
          :none,
          -1,
          nil,
        ).then do |reply|
          # call_sync unpacks the reply tuple into a Ruby array already, so
          # the one-element tuple holding the name list is flattened here.
          Array(reply).flatten
        end
      rescue GLib::Error
        []
      end
  end
end
