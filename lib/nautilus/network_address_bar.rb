# frozen_string_literal: true

require 'adwaita'
require_relative 'dialog_utilities'
require_relative 'recent_servers'

module Nautilus
  # NetworkAddressBar is the "Connect to Server" entry bar: the server
  # address entry, the Connect/Cancel button and the protocol-info popover.
  #
  # Ported from src/nautilus-network-address-bar.c and its .blp: typing a
  # recognised URI scheme (one Gio::Vfs actually supports, minus the
  # upstream-excluded afc/archive/burn/computer/file/http/localtest/obex/
  # recent/trash ones) enables Connect, mounting pulses the entry's progress
  # bar while nautilus_file_mount_enclosing_volume runs, and a successful
  # mount records the address in RecentServers and opens the mounted
  # location (`on_open_location`) when `should_open_location` is set.
  class NetworkAddressBar
    UNSUPPORTED_PROTOCOLS = %w[afc archive burn computer file http localtest obex recent trash].freeze

    PROTOCOL_ROWS = [
      ['afp', 'AppleTalk', 'afp://'],
      ['ftp', 'File Transfer Protocol', 'ftp:// or ftps://'],
      ['nfs', 'Network File System', 'nfs://'],
      ['smb', 'Samba', 'smb://'],
      ['ssh', 'SSH File Transfer Protocol', 'sftp:// or ssh://'],
      ['dav', 'WebDAV', 'dav:// or davs://'],
    ].freeze

    def initialize(on_open_location: nil)
      @on_open_location = on_open_location
      @should_open_location = false
      @connecting = false
      @cancellable = nil
      @pulse_timeout_id = nil
    end

    def build
      root.tap do |box|
        box.append(address_entry)
        box.append(connect_button)
        box.append(info_button)

        address_entry.tap do |entry|
          entry.signal_connect('notify::text') { refresh_entry_state }
          entry.signal_connect('activate') { on_connect_clicked }
          entry.signal_connect('icon-press') do |_entry, position|
            if position == :secondary
              entry.text = ''
            end
          end
        end

        connect_button.signal_connect('clicked') { on_connect_clicked }

        refresh_entry_state
        populate_protocols_grid
      end
    end

    def root
      @root ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.hexpand = true
        box.visible = false
        box.add_css_class('toolbar')
      end
    end

    def address_entry
      @address_entry ||= Gtk::Entry.new.tap do |entry|
        entry.input_purpose = :url
        entry.width_chars = 10
        entry.max_width_chars = 34
        entry.placeholder_text = 'Server address'
      end
    end

    def connect_button
      @connect_button ||= Gtk::Button.new.tap do |button|
        button.label = 'Con_nect'
        button.use_underline = true
        button.can_shrink = true
        button.sensitive = false
        button.valign = :center
      end
    end

    def info_button
      @info_button ||= Gtk::MenuButton.new.tap do |button|
        button.tooltip_text = 'Server Address Information'
        button.icon_name = 'info-outline-symbolic'
        button.popover = info_popover
        button.add_css_class('flat')
        button.add_css_class('circular')
      end
    end

    def info_popover
      @info_popover ||= Gtk::Popover.new.tap do |popover|
        popover.position = :top
        popover.child = info_box
      end
    end

    def info_box
      @info_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.margin_start = 12
        box.margin_end = 12
        box.margin_top = 12
        box.margin_bottom = 12

        box.append(Gtk::Label.new('Server Addresses').tap do |label|
          label.hexpand = true
          label.add_css_class('title-4')
        end)
        box.append(Gtk::Label.new('Server addresses are made up of a protocol prefix and an address. ' \
                                   'Examples:').tap do |label|
          label.hexpand = true
          label.wrap = true
          label.width_chars = 40
          label.max_width_chars = 40
          label.xalign = 0
        end)
        box.append(Gtk::Label.new('smb://gnome.org, ssh://192.168.0.1, ftp://[2001:db8::1]').tap do |label|
          label.hexpand = true
          label.wrap = true
          label.width_chars = 40
          label.max_width_chars = 40
          label.xalign = 0
        end)
        box.append(protocols_grid)
      end
    end

    def protocols_grid
      @protocols_grid ||= Gtk::Grid.new.tap do |grid|
        grid.margin_top = 12
        grid.hexpand = true
        grid.row_spacing = 6
        grid.column_spacing = 12
        grid.attach(Gtk::Label.new('Available Protocols').tap do |label|
          label.hexpand = true
          label.xalign = 0
          label.add_css_class('heading')
        end, 0, 0, 1, 1)
        grid.attach(Gtk::Label.new('Prefix').tap do |label|
          label.xalign = 0
          label.add_css_class('heading')
        end, 1, 0, 1, 1)
      end
    end

    private

      def supported_schemes = Gio::Vfs.default.supported_uri_schemes

      def scheme_of(address)
        match = /\A([a-zA-Z][a-zA-Z0-9+.-]*):/.match(address)
        match && match[1]
      end

      def refresh_entry_state
        address = address_entry.text
        scheme = scheme_of(address)
        supported = !scheme.nil? && supported_schemes.include?(scheme) && !UNSUPPORTED_PROTOCOLS.include?(scheme)

        address_entry.set_icon_from_icon_name(:secondary, address.empty? ? nil : 'edit-clear-symbolic')
        connect_button.sensitive = supported

        if !scheme.nil? && !supported
          address_entry.add_css_class('error')
        else
          address_entry.remove_css_class('error')
        end
      end

      def populate_protocols_grid
        row = 1
        any = false
        PROTOCOL_ROWS.each do |(scheme, name, prefix)|
          if supported_schemes.include?(scheme)
            any = true
            protocols_grid.attach(Gtk::Label.new(name).tap { |label| label.halign = :start }, 0, row, 1, 1)
            protocols_grid.attach(Gtk::Label.new(prefix).tap { |label| label.halign = :start }, 1, row, 1, 1)
            row += 1
          end
        end
        protocols_grid.visible = any
      end

      def on_connect_clicked
        if connect_button.sensitive
          if @connecting
            @cancellable&.cancel
          else
            try_connect
          end
        end
      end

      def try_connect
        address = address_entry.text
        if address.nil? || address.empty?
          show_error('Unable to get remote server location', nil)
        else
          @should_open_location = true
          mount_server(Gio::File.new_for_commandline_arg(address))
        end
      end

      def mount_server(location)
        @cancellable = Gio::Cancellable.new
        @connecting = true

        address_entry.sensitive = false
        connect_button.label = 'Cance_l'
        start_pulsing

        operation = Gtk::MountOperation.new(root.root)
        operation.password_save = :for_session

        location.mount_enclosing_volume(:none, operation, @cancellable) do |source, result|
          on_mount_ready(source, result)
        end
      end

      def start_pulsing
        address_entry.progress_pulse_step = 0.1
        address_entry.progress_fraction = 0.1
        @pulse_timeout_id ||= GLib::Timeout.add(100) do
          if @connecting
            address_entry.progress_pulse
            GLib::Source::CONTINUE
          else
            address_entry.progress_fraction = 0
            @pulse_timeout_id = nil
            GLib::Source::REMOVE
          end
        end
      end

      def on_mount_ready(source, result)
        location = source
        should_show = true

        begin
          location.mount_enclosing_volume_finish(result)
        rescue Gio::IOError::AlreadyMounted
          # Already mounted is not a critical error; continue as if it
          # succeeded.
          should_show = true
        rescue Gio::IOError::Cancelled, Gio::IOError::FailedHandled
          # Cancelled by the user, or the error has already been handled.
          should_show = false
        rescue GLib::Error => error
          should_show = false
          show_error('Unable to access location', error.message)
        end

        @connecting = false
        address_entry.sensitive = true
        connect_button.label = 'Con_nect'

        if should_show
          RecentServers.add(location)
          address_entry.text = ''

          if @should_open_location
            open_location(location)
          end
        end
      end

      def open_location(location)
        mount = location.find_enclosing_mount(nil)
        uri = mount.nil? ? location.uri : mount.default_location.uri
        @on_open_location&.call(uri)
      rescue GLib::Error
        @on_open_location&.call(location.uri)
      end

      def show_error(primary, secondary)
        DialogUtilities.dialog_with_responses(primary, secondary.to_s).present(root.root)
      end
  end
end
