# frozen_string_literal: true

require 'adwaita'
require_relative 'view_cell'
require_relative 'image'

module Nautilus
  # GridCell is one cell of the grid view: the icon, the emblems over it and
  # up to three lines of label.
  #
  # Ported from src/resources/ui/nautilus-grid-cell.blp and
  # nautilus-grid-cell.c. The label wraps over at most three lines with
  # hyphen insertion turned off and a tooltip which appears only when the
  # name is actually ellipsized, as on_label_query_tooltip() decides.
  class GridCell < ViewCell
    CAPTION_ZOOM_THRESHOLD = {
      'small'       => 0,
      'small-plus'  => 1,
      'medium'      => 1,
      'large'       => 2,
      'extra-large' => 3,
    }.freeze

    def initialize(icon_size:, captions: [], **callbacks)
      super(icon_size: icon_size, **callbacks)
      @captions = captions
    end

    def build
      super.tap do |widget|
        widget.valign = :start
        widget.append(icon_overlay)
        widget.append(labels_box)

        icon_overlay.tap do |overlay|
          overlay.child = icon.build
          overlay.add_overlay(emblems_box)
        end

        labels_box.tap do |box|
          box.append(label)
          caption_labels.each { |caption| box.append(caption) }
        end

        label.signal_connect('query-tooltip') do |_label, _x, _y, _keyboard, tooltip|
          show_tooltip?(tooltip)
        end
      end
    end

    def captions=(captions)
      @captions = captions
      refresh_captions
      captions
    end

    def icon_size=(size)
      super
      icon.pixel_size = size
      refresh_captions
      size
    end

    def icon_overlay = @icon_overlay ||= Gtk::Overlay.new

    def icon = @icon ||= Image.new(pixel_size: icon_size)

    def emblems_box
      @emblems_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.halign = :end
        box.valign = :start
        box.margin_start = 2
        box.add_css_class('dim-label')
      end
    end

    def labels_box
      @labels_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.add_css_class('icon-ui-labels-box')
      end
    end

    def label
      @label ||= Gtk::Label.new.tap do |widget|
        widget.has_tooltip = true
        widget.ellipsize = :middle
        widget.justify = :center
        widget.lines = 3
        widget.wrap = true
        widget.wrap_mode = :word_char
        # The blueprint also sets `attributes: "0 -1 insert-hyphens false"`,
        # so a wrapped filename is not hyphenated. Pango::AttrInsertHyphens
        # has no Ruby binding, and :word_char wrapping without it is the
        # closest this gets.
      end
    end

    # The three caption labels under the name. How many of them are shown
    # depends on the zoom level, as nautilus_grid_cell_set_caption_attributes
    # does: the smallest zoom shows none.
    def caption_labels
      @caption_labels ||= Array.new(3) do
        Gtk::Label.new.tap do |widget|
          widget.ellipsize = :middle
          widget.justify = :center
          widget.add_css_class('dim-label')
          widget.add_css_class('caption')
        end
      end
    end

    private

      def show(item)
        icon.file = item
        label.label = item.display_name
        refresh_emblems(item)
        refresh_captions
      end

      def refresh_emblems(item)
        emblems_box.tap do |box|
          while (child = box.first_child)
            box.remove(child)
          end
          emblem_names(item).each do |name|
            box.append(Gtk::Image.new.tap { |image| image.icon_name = name })
          end
        end
      end

      # The emblems upstream draws over an icon: a link, a starred file, and
      # one for a file the user cannot write to.
      def emblem_names(item)
        [].tap do |names|
          if item.symlink?
            names << 'emblem-symbolic-link'
          end
          if item.starred?
            names << 'starred-symbolic'
          end
          unless item.can_write?
            names << 'emblem-readonly'
          end
        end
      end

      def refresh_captions
        visible_caption_count.then do |count|
          caption_labels.each_with_index do |widget, index|
            widget.label = caption_text(index)
            widget.visible = index < count && !caption_text(index).empty?
          end
        end
      end

      def visible_caption_count
        CAPTION_ZOOM_THRESHOLD.fetch(zoom_level_name, 1)
      end

      def zoom_level_name
        { 48 => 'small', 64 => 'small-plus', 96 => 'medium', 168 => 'large', 256 => 'extra-large' }
          .fetch(icon_size, 'medium')
      end

      def caption_text(index)
        @captions.fetch(index, 'none').then do |attribute|
          if attribute == 'none' || item.nil?
            ''
          else
            item.attribute(attribute)
          end
        end
      end

      # on_label_query_tooltip(): the tooltip is the full name, and only
      # appears when the label could not show all of it.
      def show_tooltip?(tooltip)
        if label.layout.ellipsized? || label.layout.line_count > 3
          tooltip.set_text(label.label)
          true
        else
          false
        end
      end
  end
end
