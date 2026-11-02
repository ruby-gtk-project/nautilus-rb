# frozen_string_literal: true

require 'adwaita'
require_relative 'dbus_launcher'

module Nautilus
  # LocationBanner is the banner a slot shows above its view for the handful
  # of locations that need explaining.
  #
  # Ported from src/nautilus-location-banner.c: the six modes it switches
  # between, with the two Sharing variants and the trash's auto-emptied
  # wording making up the eleven configurations. The trash banner is revealed
  # only while the trash has something in it, and the auto-emptied title
  # names the age at which files go, read from the desktop privacy settings.
  class LocationBanner
    MODES = %i[none scripts sharing templates trash trash_auto_emptied].freeze

    # The scripts folder upstream looks for, under the nautilus data dir.
    SCRIPTS_PATH = ::File.join(
      ENV.fetch('XDG_DATA_HOME', ::File.expand_path('~/.local/share')),
      'nautilus',
      'scripts',
    )

    TEMPLATES_PATH = ::File.join(Dir.home, 'Templates')
    PUBLIC_SHARE_PATH = ::File.join(Dir.home, 'Public')

    def initialize(on_empty_trash: nil)
      @on_empty_trash = on_empty_trash
      @mode = :none
      @old_files_age = 30
      @remove_old_trash_files = false
      @shared_connections = []
      @trash_empty = true
    end

    attr_reader :mode

    # The three values upstream reads from org.gnome.desktop.privacy and
    # org.gnome.desktop.file-sharing, whose schemas are not installed in a
    # checkout. The app feeds them in so the trash and sharing banners say
    # what they say upstream.
    attr_writer :old_files_age, :remove_old_trash_files, :shared_connections

    def build
      banner.tap do |widget|
        widget.signal_connect('button-clicked') do
          on_button_clicked
        end
      end
    end

    def banner = @banner ||= Adwaita::Banner.new('')

    # nautilus_location_banner_load().
    def location=(location)
      load_mode(mode_for_location(location))
      location
    end

    # The trash monitor's state, which decides whether the trash banner is
    # revealed at all.
    def trash_empty=(empty)
      @trash_empty = empty
      if %i[trash trash_auto_emptied].include?(@mode)
        banner.revealed = !empty
      end
      empty
    end

    def mode_for_location(location)
      if location.nil?
        :none
      elsif templates?(location)
        :templates
      elsif scripts?(location)
        :scripts
      elsif public_share?(location)
        :sharing
      elsif location.uri.start_with?('trash:')
        trash_mode
      else
        :none
      end
    end

    private

      def trash_mode
        if @remove_old_trash_files
          :trash_auto_emptied
        else
          :trash
        end
      end

      def templates?(location)
        ::File.directory?(TEMPLATES_PATH) && location.path == TEMPLATES_PATH
      end

      def scripts?(location) = location.path == SCRIPTS_PATH

      def public_share?(location)
        ::File.directory?(PUBLIC_SHARE_PATH) && location.path == PUBLIC_SHARE_PATH
      end

      def load_mode(mode)
        @mode = mode
        case mode
        when :none then apply_none
        when :scripts then apply_scripts
        when :sharing then apply_sharing
        when :templates then apply_templates
        when :trash then apply_trash
        when :trash_auto_emptied then apply_trash_auto_emptied
        end
      end

      def apply_none
        banner.revealed = false
      end

      def apply_scripts
        apply(
          'Executable files in this folder will appear in the Scripts menu',
          nil,
          revealed: true,
        )
      end

      def apply_sharing
        apply(sharing_title, 'Sharing Settings', revealed: true)
      end

      def sharing_title
        if @shared_connections.empty?
          'Turn on File Sharing to share this folder over the network'
        else
          'This folder is shared over the network'
        end
      end

      def apply_templates
        apply(
          'Put files in this folder to use them as templates for new documents',
          '_Learn More',
          revealed: true,
        )
      end

      def apply_trash
        apply('', '_Empty Trash…', revealed: !@trash_empty)
      end

      def apply_trash_auto_emptied
        apply(auto_emptied_message, '_Trash Settings', revealed: true)
      end

      # parse_old_files_age_preferences_value().
      def auto_emptied_message
        if @old_files_age.zero?
          'Files in the trash are permanently deleted after 1 hour'
        elsif @old_files_age == 1
          'Files in the trash are permanently deleted after 1 day'
        else
          "Files in the trash are permanently deleted after #{@old_files_age} days"
        end
      end

      def apply(title, button_label, revealed:)
        banner.tap do |widget|
          widget.title = title
          widget.button_label = button_label.to_s
          widget.revealed = revealed
        end
      end

      def on_button_clicked
        case @mode
        when :sharing then DBusLauncher.instance.open_settings_panel('sharing')
        when :templates then learn_more
        when :trash then @on_empty_trash&.call
        when :trash_auto_emptied then DBusLauncher.instance.open_settings_panel('privacy')
        end
      end

      def learn_more
        Gtk::UriLauncher.new('help:gnome-help/files-templates').launch(banner.root, nil)
      rescue GLib::Error
        nil
      end
  end
end
