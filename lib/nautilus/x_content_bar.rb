# frozen_string_literal: true

require 'gtk4'

module Nautilus
  # XContentBar is the removable-media info bar offering to open the
  # mount's content with the app registered for it (photos, music, video
  # discs, installable software, …).
  #
  # Ported from src/nautilus-x-content-bar.c: the bold ellipsized message
  # built from the mount's x-content types, one response button per
  # distinct default app (apps shared by several content types collapse to
  # one button, matching the C de-duplication loop), and launching that
  # app on the mount's root when a button is pressed.
  #
  # Content types nautilus-file-utilities.c calls out by name get their own
  # phrasing; any other type that does have a handler app falls back to
  # "Detected as “%s”". should_handle_content_type?/should_handle_content_types?
  # are nautilus_file_utilities' gate for creating the bar at all: a blank
  # disc or a type with no app for it is not offered here.
  class XContentBar
    # g_content_type_is_a() has no binding in this gio2 build (introspection
    # has no `is_a`/`get_description` method on Gio::ContentType), so the
    # win32-software check below is an exact match rather than a hierarchy
    # check — adequate here since every x-content/* type nautilus deals
    # with is already a leaf type.
    def self.should_handle_content_type?(content_type)
      !content_type.start_with?('x-content/blank-') &&
        content_type != 'x-content/win32-software' &&
        !Gio::AppInfo.get_default_for_type(content_type, false).nil?
    end

    def self.should_handle_content_types?(content_types)
      content_types.any? { |type| should_handle_content_type?(type) }
    end

    def initialize(mount, x_content_types)
      @mount = mount
      @x_content_types = x_content_types.select { |type| self.class.should_handle_content_type?(type) }
    end

    def build
      info_bar.tap do |bar|
        bar.message_type = :question
        bar.add_child(label)
        bar.signal_connect('response') { |_bar, response_id| on_response(response_id) }
        apps_by_button.each_key { |app_id| bar.add_button(apps_by_button[app_id][:name], apps_by_button[app_id][:response]) }
      end
    end

    def widget = info_bar

    private

      def label
        @label ||= Gtk::Label.new(message).tap do |lbl|
          lbl.attributes = Pango::AttrList.new.tap { |attrs| attrs.insert(Pango::AttrWeight.new(:bold)) }
          lbl.ellipsize = :end
        end
      end

      def info_bar = @info_bar ||= Gtk::InfoBar.new

      def on_response(response_id)
        if response_id >= 0
          content_type = @x_content_types[response_id]
          if content_type
            app = Gio::AppInfo.get_default_for_type(content_type, false)
            app&.launch([@mount.root], nil)
          end
        end
      end

      # Button n is added only the first time its default app shows up, so
      # the response id doubles as the index into @x_content_types.
      def apps_by_button
        @apps_by_button ||= {}.tap do |seen|
          @x_content_types.each_with_index do |content_type, index|
            app = Gio::AppInfo.get_default_for_type(content_type, false)
            if app && seen.values.none? { |entry| entry[:app] == app }
              seen[app.id] = {app: app, name: app.name, response: index}
            end
          end
        end
      end

      def message
        case @x_content_types.length
        when 1 then message_for(@x_content_types[0])
        when 2 then message_for_two(@x_content_types[0], @x_content_types[1])
        else 'Open with:'
        end
      end

      # g_content_type_get_description() has no binding in this gio2 build
      # either, so the well-known types fall back to the raw content-type
      # string rather than its localized friendly description.
      def message_for(content_type)
        case content_type
        when 'x-content/image-photocd' then 'Photo CD'
        when 'x-content/image-dcf' then 'Contains digital photos'
        when 'x-content/audio-player' then 'Contains music'
        when 'x-content/unix-software' then 'Contains software to run'
        when 'x-content/ostree-repository' then 'Contains software to install'
        else "Detected as “%s”" % content_type
        end
      end

      def message_for_two(first, second)
        if [first, second].include?('x-content/image-dcf')
          if first == 'x-content/audio-player'
            'Contains music and photos'
          elsif second == 'x-content/audio-player'
            'Contains photos and music'
          else
            'Contains digital photos'
          end
        elsif [first, second].include?('x-content/video-vcd') && [first, second].include?('x-content/video-dvd')
          "#{message_for(first)}/#{message_for(second)}"
        else
          message_for(first)
        end
      end
  end
end
