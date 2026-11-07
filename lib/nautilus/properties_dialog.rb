# frozen_string_literal: true

require 'adwaita'
require 'gexiv2'
require 'glycin'
require 'libglycin-gtk4'
require 'gstreamer_pbutils'

module Nautilus
  # PropertiesDialog shows a file's basic attributes, and, for the types
  # upstream's own properties extensions cover, the metadata those
  # extensions read.
  #
  # Ported from src/nautilus-properties-window.c for the basic page, from
  # extensions/image-properties/nautilus-image-properties-model.c for the
  # image rows (read with GExiv2::Metadata — EXIF/IPTC/XMP), and from
  # extensions/audio-video-properties/totem-properties-view.c for the
  # audio/video rows (read with GstPbutils::Discoverer, the same
  # synchronous, single-shot discovery upstream's extension runs on its own
  # worker thread). gexiv2 and gstreamer_pbutils fail softly here: a file
  # Exiv2 or GStreamer cannot parse still gets the basic page, just without
  # the extra group.
  class PropertiesDialog
    def initialize(file)
      @file = file
    end

    def build = dialog

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |window|
        window.title = "#{@file.display_name} Properties"
        window.content_width = 420
        window.content_height = 360
      end
    end

    private

      def toolbar_view
        @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
          dialog.child = view
          view.add_top_bar(Adwaita::HeaderBar.new)
          view.content = scroller
        end
      end

      def scroller
        @scroller ||= Gtk::ScrolledWindow.new.tap do |s|
          s.child = page
          build_page
        end
      end

      def page
        @page ||= Adwaita::PreferencesPage.new
      end

      def build_page
        toolbar_view
        page.add(basic_group)
        image_group.tap { |group| page.add(group) unless group.nil? }
        media_group.tap { |group| page.add(group) unless group.nil? }
      end

      def basic_group
        @basic_group ||= Adwaita::PreferencesGroup.new.tap do |group|
          group.title = 'Basic'
          group.add(info_row('Name', @file.display_name))
          group.add(info_row('Type', @file.content_type))
          group.add(info_row('Size', @file.size_string))
          group.add(info_row('Location', @file.parent&.parse_name.to_s))
        end
      end

      # append_gexiv_basic_info() / append_gexiv2_info(): dimensions,
      # orientation and the handful of EXIF/XMP tags upstream's image
      # extension shows, read straight off the file with GExiv2::Metadata.
      # glycin's decode is used only for the pixel size when Exiv2 itself
      # could not read one (an image format Exiv2 has no reader for, but
      # glycin's sandboxed loaders do).
      def image_group
        return nil unless @file.content_type.start_with?('image/') && @file.path

        metadata = image_metadata
        return nil if metadata.nil?

        Adwaita::PreferencesGroup.new.tap do |group|
          group.title = 'Image'
          group.add(info_row('Dimensions', dimensions_text(metadata)))
          tag_row(group, metadata, 'Exif.Image.Make', 'Camera Brand')
          tag_row(group, metadata, 'Exif.Image.Model', 'Camera Model')
          tag_row(group, metadata, 'Exif.Photo.ExposureTime', 'Exposure Time')
          tag_row(group, metadata, 'Exif.Photo.FNumber', 'Aperture Value')
          tag_row(group, metadata, 'Exif.Photo.ISOSpeedRatings', 'ISO Speed Rating')
        end
      end

      def image_metadata
        GExiv2::Metadata.new.tap { |md| md.open_path(@file.path) }
      rescue GLib::Error
        nil
      end

      def dimensions_text(metadata)
        width = metadata.pixel_width
        height = metadata.pixel_height
        if width.to_i.zero? || height.to_i.zero?
          glycin_dimensions_text
        else
          "#{width} × #{height}"
        end
      end

      # Falls back to glycin's own decode for a format Exiv2 cannot size
      # (gexiv2_metadata_get_pixel_width() returns 0 for those), matching
      # why nautilus-icon-info.c turns to glycin at all: GdkPixbuf/Exiv2
      # coverage and glycin's sandboxed-loader coverage do not fully
      # overlap.
      #
      # This uses Gly::Frame#width/#height directly rather than going
      # through libglycin-gtk4 for a GdkTexture: that gem's GTK4 glue
      # (namespace GlyGtk4, not the Ruby constant `LibglycinGtk4` its own
      # require implies) has no callable API through this binding. The
      # typelib's own "Loader" GI class is shadowed by
      # gobject-introspection's bootstrap class of the same name — confirmed
      # with nix develop --command ruby -e 'require "glycin"; require
      # "libglycin-gtk4"; p GlyGtk4::Loader.ancestors' showing
      # [GlyGtk4::Loader, GObjectIntrospection::Loader, Object] — so
      # GlyGtk4::Loader.load never reaches gly_gtk4_frame_get_texture();
      # it raises ArgumentError against the bootstrap loader's own
      # `#load(namespace, base_module, options = {})` instead. libglycin-gtk4
      # is loadable (`require "libglycin-gtk4"` succeeds) but has no usable
      # entry point from Ruby.
      def glycin_dimensions_text
        image = Gly::Loader.new(file: Gio::File.new_for_path(@file.path)).load
        frame = image.next_frame
        "#{frame.width} × #{frame.height}"
      rescue GLib::Error, Gly::Error
        ''
      end

      def tag_row(group, metadata, tag, label)
        if metadata.has_tag?(tag)
          value = metadata.get_tag_interpreted_string(tag)
          group.add(info_row(label, value)) unless value.nil? || value.empty?
        end
      rescue GLib::Error
        nil
      end

      # append_audio_video_properties(): duration and the codec/stream
      # details totem-properties-view.c reads off a GstDiscovererInfo.
      # Discoverer.discover_uri() is synchronous, which is exactly the
      # upstream extension's own worker-thread call made inline here since
      # this port has no equivalent background job.
      def media_group
        return nil unless @file.content_type.start_with?('audio/') || @file.content_type.start_with?('video/')

        info = discover_info
        return nil if info.nil?

        Adwaita::PreferencesGroup.new.tap do |group|
          group.title = 'Media'
          group.add(info_row('Duration', duration_text(info)))
          video_info(info)&.then { |video| group.add(info_row('Dimensions', "#{video.width} × #{video.height}")) }
          audio_info(info)&.then { |audio| group.add(info_row('Channels', audio.channels.to_s)) }
        end
      end

      def discover_info
        GstPbutils::Discoverer.new(5_000_000_000).discover_uri(@file.uri)
      rescue GLib::Error
        nil
      end

      def duration_text(info)
        seconds = info.duration / 1_000_000_000
        format('%<m>d:%<s>02d', m: seconds / 60, s: seconds % 60)
      end

      def video_info(info) = info.video_streams.first

      def audio_info(info) = info.audio_streams.first

      def info_row(title, value)
        Adwaita::ActionRow.new.tap do |row|
          row.title = title
          row.subtitle = value.to_s
        end
      end
  end
end
