# frozen_string_literal: true

require 'adwaita'
require_relative 'global_preferences'

module Nautilus
  # Image paints a file's icon or thumbnail at the size the view asks for.
  #
  # Ported from src/nautilus-image.c, which is a Gtk.Widget that snapshots the
  # icon itself so it can frame a thumbnail, draw the video film holes and
  # scale without GtkImage's rounding. The paint code there is 900 lines of
  # GtkSnapshot work with no Ruby counterpart; what the cells use it for is a
  # fixed-size icon which gains the `image-frame` and `file-thumbnail`
  # classes once it is showing a real thumbnail rather than a symbolic icon,
  # and that is what this builds, with style.css supplying the frame.
  class Image
    def initialize(pixel_size: 32)
      @pixel_size = pixel_size
    end

    attr_reader :pixel_size

    def build = image

    def pixel_size=(size)
      @pixel_size = size
      image.pixel_size = size
      size
    end

    # Shows `file`'s icon, or its thumbnail when the file is an image small
    # enough for the thumbnail-limit preference to allow one.
    def file=(file)
      if file.nil?
        clear
      else
        show(file)
      end
      file
    end

    def image
      @image ||= Gtk::Image.new.tap do |widget|
        widget.pixel_size = @pixel_size
        widget.halign = :center
        widget.valign = :center
        widget.add_css_class('nautilus-image')
      end
    end

    private

      def clear
        image.tap do |widget|
          widget.clear
          widget.remove_css_class('image-frame')
          widget.remove_css_class('file-thumbnail')
        end
      end

      def show(file)
        thumbnail_path(file).then do |path|
          if path.nil?
            show_icon(file)
          else
            show_thumbnail(path)
          end
        end
      end

      def show_icon(file)
        image.tap do |widget|
          widget.remove_css_class('image-frame')
          widget.remove_css_class('file-thumbnail')
          widget.gicon = file.icon
        end
      end

      def show_thumbnail(path)
        image.tap do |widget|
          widget.add_css_class('image-frame')
          widget.add_css_class('file-thumbnail')
          widget.set_file(path)
        end
      end

      # An image file is its own thumbnail source. Upstream asks the
      # thumbnail factory for a cached thumbnail and falls back to the icon;
      # the limit preference, in megabytes, is honoured either way.
      def thumbnail_path(file)
        if thumbnailable?(file)
          file.path
        end
      end

      def thumbnailable?(file)
        file.content_type.start_with?('image/') &&
          !file.path.nil? &&
          file.size <= (GlobalPreferences.instance.preferences['thumbnail-limit'] * 1024 * 1024) &&
          GlobalPreferences.instance.preferences['show-image-thumbnails'] != 'never'
      end
  end
end
