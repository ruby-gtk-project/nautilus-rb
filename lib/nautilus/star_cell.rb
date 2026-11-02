# frozen_string_literal: true

require 'adwaita'
require_relative 'view_cell'

module Nautilus
  # StarCell is the starred column's cell: a button toggling the star.
  #
  # Ported from src/nautilus-star-cell.c. The button carries the `star` class
  # style.css styles, and the `interacted` class which runs the rotate
  # animation — added only once the user has clicked, so rebinding a row does
  # not animate it.
  class StarCell < ViewCell
    STARRED_ICON = 'starred-symbolic'
    UNSTARRED_ICON = 'non-starred-symbolic'

    def initialize(on_toggled: nil, **callbacks)
      super(**callbacks)
      @on_toggled = on_toggled
    end

    def build
      super.tap do |widget|
        widget.orientation = :horizontal
        widget.append(button)

        button.signal_connect('clicked') do
          toggle
        end
      end
    end

    def button
      @button ||= Gtk::Button.new.tap do |widget|
        widget.valign = :center
        widget.halign = :center
        widget.add_css_class('star')
        widget.add_css_class('flat')
        widget.icon_name = UNSTARRED_ICON
      end
    end

    private

      def show(item)
        button.icon_name = icon_name_for(item)
        button.tooltip_text = tooltip_for(item)
        button.remove_css_class('interacted')
        apply_starred_class(item.starred?)
      end

      def toggle
        unless item.nil?
          item.starred = !item.starred?
          button.add_css_class('interacted')
          button.icon_name = icon_name_for(item)
          button.tooltip_text = tooltip_for(item)
          apply_starred_class(item.starred?)
          @on_toggled&.call(item)
        end
      end

      def apply_starred_class(starred)
        if starred
          button.add_css_class('starred')
        else
          button.remove_css_class('starred')
        end
      end

      def icon_name_for(item)
        if item.starred?
          STARRED_ICON
        else
          UNSTARRED_ICON
        end
      end

      def tooltip_for(item)
        if item.starred?
          'Unstar'
        else
          'Star'
        end
      end
  end
end
