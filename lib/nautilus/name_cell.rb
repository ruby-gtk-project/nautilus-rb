# frozen_string_literal: true

require 'adwaita'
require_relative 'view_cell'
require_relative 'image'

module Nautilus
  # NameCell is the name column's cell: the tree expander, the icon, the name,
  # the path a search result was found at, the emblems and the full-text
  # match snippet.
  #
  # Ported from src/resources/ui/nautilus-name-cell.blp and
  # nautilus-name-cell.c. The path label is shown only for a search result or
  # a recent file, and the snippet button only when the search matched the
  # file's contents — both hidden by default, as the blueprint has them.
  class NameCell < ViewCell
    def build
      super.tap do |widget|
        widget.orientation = :horizontal
        widget.append(expander)

        expander.child = content

        content.tap do |box|
          box.append(fixed_height_box)
          box.append(labels_box)
          box.append(snippet_button)

          fixed_height_box.center_widget = icon.build

          labels_box.tap do |labels|
            labels.append(name_row)
            labels.append(path_label)

            name_row.tap do |row|
              row.append(label)
              row.append(emblems_box)
              row.append(spinner)
            end
          end
        end

        label.signal_connect('query-tooltip') do |_label, _x, _y, _keyboard, tooltip|
          show_tooltip?(tooltip)
        end
      end
    end

    def icon_size=(size)
      super
      icon.pixel_size = size
      fixed_height_box.width_request = size
      fixed_height_box.height_request = size
      size
    end

    # Set by the list view when the location's items can be expanded in
    # place, which is what the use-tree-view preference turns on.
    def tree_list_row=(row)
      expander.list_row = row
      row
    end

    def expander
      @expander ||= Gtk::TreeExpander.new.tap do |widget|
        widget.indent_for_icon = false
        widget.focusable = false
      end
    end

    def content
      @content ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.halign = :fill
        box.valign = :center
      end
    end

    def fixed_height_box
      @fixed_height_box ||= Gtk::CenterBox.new.tap do |box|
        box.valign = :center
        box.width_request = icon_size
        box.height_request = icon_size
      end
    end

    def icon = @icon ||= Image.new(pixel_size: icon_size)

    def labels_box
      @labels_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.halign = :fill
        box.hexpand = true
        box.valign = :center
        box.add_css_class('column-name-labels-box')
      end
    end

    def name_row
      @name_row ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.halign = :fill
        box.hexpand = true
      end
    end

    def label
      @label ||= Gtk::Label.new.tap do |widget|
        widget.ellipsize = :middle
        widget.lines = 1
        widget.max_width_chars = -1
        widget.wrap = false
        widget.halign = :start
        widget.has_tooltip = true
      end
    end

    def emblems_box
      @emblems_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.halign = :start
        box.add_css_class('dim-label')
      end
    end

    def spinner
      @spinner ||= Adwaita::Spinner.new.tap do |widget|
        widget.visible = false
        widget.halign = :center
        widget.valign = :center
      end
    end

    def path_label
      @path_label ||= Gtk::Label.new.tap do |widget|
        widget.visible = false
        widget.ellipsize = :start
        widget.justify = :left
        widget.halign = :fill
        widget.xalign = 0.0
        widget.add_css_class('caption')
        widget.add_css_class('dim-label')
      end
    end

    def snippet_button
      @snippet_button ||= Gtk::MenuButton.new.tap do |button|
        button.tooltip_text = 'Full Text Match'
        button.visible = false
        button.icon_name = 'quotation-symbolic'
        button.valign = :center
        button.add_css_class('fts-snippet')
        button.popover = snippet_popover
      end
    end

    def snippet_popover
      @snippet_popover ||= Gtk::Popover.new.tap do |popover|
        popover.child = snippet_label
      end
    end

    def snippet_label
      @snippet_label ||= Gtk::Label.new.tap do |widget|
        widget.ellipsize = :none
        widget.justify = :left
        widget.max_width_chars = 65
        widget.lines = 10
        widget.wrap = true
        widget.wrap_mode = :word
      end
    end

    # The path a search hit was found at, shown under the name.
    def show_path(path)
      path_label.label = path.to_s
      path_label.visible = !path.to_s.empty?
    end

    # The matched text of a full-text search hit.
    def show_snippet(snippet)
      snippet_label.label = snippet.to_s
      snippet_button.visible = !snippet.to_s.empty?
    end

    private

      def show(item)
        icon.file = item
        label.label = item.display_name
        refresh_emblems(item)
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

      def emblem_names(item)
        [].tap do |names|
          if item.symlink?
            names << 'emblem-symbolic-link'
          end
          unless item.can_write?
            names << 'emblem-readonly'
          end
        end
      end

      def show_tooltip?(tooltip)
        if label.layout.ellipsized?
          tooltip.set_text(label.label)
          true
        else
          false
        end
      end
  end
end
