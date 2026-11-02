# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # SidebarRow is one place in the sidebar.
  #
  # Ported from src/resources/ui/nautilus-sidebar-row.blp and
  # nautilus-sidebar-row.c: a revealer wrapping the icon, the ellipsized
  # label, an optional end icon, the eject button and the busy spinner. The
  # revealer is how a row animates in and out, and `has-open-popup` is added
  # while this row's context menu is up.
  class SidebarRow
    PLACE_KINDS = %i[
      built_in bookmark mount volume drive network other_locations starred_location trash
    ].freeze

    def initialize(place)
      @place = place
    end

    attr_reader :place

    def build
      root.tap do |row|
        row.child = revealer

        revealer.child = box

        box.tap do |container|
          container.append(start_icon_widget)
          container.append(label_widget)
          container.append(end_icon_widget)
          container.append(eject_button)
          container.append(busy_spinner)
        end

        revealer.signal_connect('notify::child-revealed') do
          on_child_revealed
        end

        show(@place)
      end
    end

    def place=(place)
      @place = place
      show(place)
      place
    end

    def reveal = revealer.reveal_child = true

    def unreveal = revealer.reveal_child = false

    def ejectable=(ejectable)
      eject_button.visible = ejectable
      ejectable
    end

    def busy=(busy)
      busy_spinner.visible = busy
      busy
    end

    def has_open_popup=(open)
      if open
        root.add_css_class('has-open-popup')
      else
        root.remove_css_class('has-open-popup')
      end
      open
    end

    def on_eject(&handler)
      eject_button.signal_connect('clicked') { handler.call(@place) }
    end

    def root
      @root ||= Gtk::ListBoxRow.new.tap do |row|
        row.focus_on_click = false
      end
    end

    def revealer
      @revealer ||= Gtk::Revealer.new.tap do |widget|
        widget.reveal_child = true
        widget.add_css_class('sidebar-revealer')
      end
    end

    def box = @box ||= Gtk::Box.new(:horizontal, 0)

    def start_icon_widget
      @start_icon_widget ||= Gtk::Image.new.tap do |image|
        image.margin_end = 8
      end
    end

    def label_widget
      @label_widget ||= Gtk::Label.new.tap do |label|
        label.hexpand = true
        label.xalign = 0
        label.ellipsize = :middle
        label.margin_end = 2
      end
    end

    def end_icon_widget
      @end_icon_widget ||= Gtk::Image.new.tap do |image|
        image.visible = false
        image.hexpand = true
        image.halign = :end
        image.valign = :center
        image.margin_end = 8
      end
    end

    def eject_button
      @eject_button ||= Gtk::Button.new.tap do |button|
        button.halign = :center
        button.valign = :center
        button.margin_start = 4
        button.icon_name = 'media-eject-symbolic'
        button.visible = false
        button.add_css_class('sidebar-button')
      end
    end

    def busy_spinner
      @busy_spinner ||= Adwaita::Spinner.new.tap do |spinner|
        spinner.halign = :center
        spinner.valign = :center
        spinner.margin_start = 4
        spinner.margin_end = 4
        spinner.visible = false
        spinner.opacity = 0.7
      end
    end

    private

      def show(place)
        label_widget.label = place.label
        label_widget.tooltip_text = place.tooltip
        start_icon_widget.icon_name = place.icon_name
        eject_button.visible = place.ejectable?
      end

      # The row is dropped from the list only once its slide-out has played
      # out, which is what notify::child-revealed waits for.
      def on_child_revealed
        unless revealer.child_revealed?
          root.parent&.remove(root)
        end
      end
  end
end
