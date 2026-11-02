# frozen_string_literal: true

require 'adwaita'
require_relative 'ui_utilities'

module Nautilus
  # HistoryControls is the back/forward pair, with a history menu on each.
  #
  # Ported from src/resources/ui/nautilus-history-controls.blp and
  # nautilus-history-controls.c. The buttons drive `slot.back` and
  # `slot.forward`; a secondary click or a long press fills the matching
  # popover from the slot's history and pops it up, with each entry targeting
  # `slot.back-n` or `slot.forward-n` at its distance from the current
  # location. A middle click opens that history entry in a new tab.
  class HistoryControls
    def initialize(window_slot: nil, on_open_in_new_tab: nil)
      @window_slot = window_slot
      @on_open_in_new_tab = on_open_in_new_tab
    end

    attr_reader :window_slot

    def window_slot=(window_slot)
      @window_slot = window_slot
    end

    def build
      root.tap do |bin|
        bin.child = box

        box.tap do |container|
          container.append(back_button)
          container.append(forward_button)
        end

        back_menu.set_parent(back_button)
        forward_menu.set_parent(forward_button)

        install_gestures(back_button, :back)
        install_gestures(forward_button, :forward)
      end
    end

    def root = @root ||= Adwaita::Bin.new

    def box = @box ||= Gtk::Box.new(:horizontal, 6)

    def back_button
      @back_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = 'Back'
        button.valign = :center
        button.action_name = 'slot.back'
        button.icon_name = 'go-previous-symbolic'
      end
    end

    def forward_button
      @forward_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = 'Forward'
        button.valign = :center
        button.action_name = 'slot.forward'
        button.icon_name = 'go-next-symbolic'
      end
    end

    def back_menu = @back_menu ||= Gtk::PopoverMenu.new(Gio::Menu.new)

    def forward_menu = @forward_menu ||= Gtk::PopoverMenu.new(Gio::Menu.new)

    private

      def install_gestures(button, direction)
        button.add_controller(long_press_gesture(direction))
        button.add_controller(click_gesture(direction))
      end

      def long_press_gesture(direction)
        Gtk::GestureLongPress.new.tap do |gesture|
          gesture.signal_connect('pressed') do
            show_menu(direction)
          end
        end
      end

      # Button 0 means every button, because this one gesture handles the
      # middle and secondary cases and denies the primary one, which the
      # button's own action handles.
      def click_gesture(direction)
        Gtk::GestureClick.new.tap do |gesture|
          gesture.button = 0
          gesture.signal_connect('pressed') do |click, _n_press, _x, _y|
            on_button_press(click, direction)
          end
        end
      end

      def on_button_press(gesture, direction)
        case gesture.current_button
        when Gdk::BUTTON_PRIMARY
          gesture.set_state(:denied)
        when Gdk::BUTTON_MIDDLE
          @on_open_in_new_tab&.call(direction)
        when Gdk::BUTTON_SECONDARY
          show_menu(direction)
        end
      end

      def show_menu(direction)
        menu_for(direction).tap do |popover|
          popover.menu_model = UiUtilities.build_menu(history_entries(direction))
          popover.popup
        end
      end

      def menu_for(direction)
        if direction == :back
          back_menu
        else
          forward_menu
        end
      end

      # fill_menu(): the entries count outwards from the current location,
      # negative going back and positive going forward.
      def history_entries(direction)
        history(direction).each_with_index.map do |location, index|
          {
            label:       location.display_name,
            action:      "slot.#{direction}-n",
            target:      step(direction, index).to_s,
            target_type: 'i',
          }
        end
      end

      def step(direction, index)
        if direction == :back
          -(index + 1)
        else
          index + 1
        end
      end

      def history(direction)
        if @window_slot.nil?
          []
        elsif direction == :back
          @window_slot.back_history
        else
          @window_slot.forward_history
        end
      end
  end
end
