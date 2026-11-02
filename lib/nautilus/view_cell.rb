# frozen_string_literal: true

require 'adwaita'
require_relative 'global_preferences'

module Nautilus
  # ViewCell is the base of every cell widget the three views bind.
  #
  # Ported from src/nautilus-view-cell.c: the widget a Gtk::ListItem's child
  # is set to, holding the item it is showing, the position it is at, and the
  # icon size the view is zoomed to. Upstream's cells are GtkWidget
  # subclasses with the controllers attached by the list base; here the
  # controllers are attached in #build so the cell owns them, and the view
  # passes the callbacks it wants called.
  class ViewCell
    def initialize(icon_size: 32, on_activate: nil, on_context_menu: nil)
      @icon_size = icon_size
      @on_activate = on_activate
      @on_context_menu = on_context_menu
      @position = nil
      @item = nil
    end

    attr_reader :icon_size, :position, :item

    def build
      root.tap do |widget|
        widget.add_controller(click_gesture)
        widget.add_controller(secondary_gesture)
        widget.add_controller(long_press_gesture)
      end
    end

    # Called by the view's bind handler. Subclasses override #show.
    def bind(item, position)
      @item = item
      @position = position
      show(item)
    end

    def unbind
      @item = nil
      @position = nil
    end

    def icon_size=(size)
      @icon_size = size
      size
    end

    def root
      @root ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.add_css_class('nautilus-view-cell')
      end
    end

    private

      def show(item) = item

      # A double click activates, which is what click-policy "double" means;
      # under "single" the first click is enough.
      def click_gesture
        @click_gesture ||= Gtk::GestureClick.new.tap do |gesture|
          gesture.button = Gdk::BUTTON_PRIMARY
          gesture.signal_connect('pressed') do |_gesture, n_press, _x, _y|
            if activates?(n_press)
              @on_activate&.call(@position)
            end
          end
        end
      end

      def activates?(n_press)
        if GlobalPreferences.instance.preferences['click-policy'] == 'single'
          n_press == 1
        else
          n_press >= 2
        end
      end

      def secondary_gesture
        @secondary_gesture ||= Gtk::GestureClick.new.tap do |gesture|
          gesture.button = Gdk::BUTTON_SECONDARY
          gesture.signal_connect('pressed') do |_gesture, _n_press, x, y|
            @on_context_menu&.call(@position, x, y)
          end
        end
      end

      # Touch screens have no secondary button, so a long press opens the
      # same menu.
      def long_press_gesture
        @long_press_gesture ||= Gtk::GestureLongPress.new.tap do |gesture|
          gesture.touch_only = true
          gesture.signal_connect('pressed') do |_gesture, x, y|
            @on_context_menu&.call(@position, x, y)
          end
        end
      end
  end
end
