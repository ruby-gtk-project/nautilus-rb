# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # FloatingBar is the status bar overlaid on the bottom right of a view.
  #
  # Ported from src/nautilus-floating-bar.c: a spinner, a primary label, a
  # details label and a stop button, with the `floating-bar` class style.css
  # rounds and shades. It gets out of the pointer's way: once the pointer is
  # over it, it hides, and it comes back as soon as the pointer leaves the
  # rectangle it occupied, checked on a 100ms timeout exactly as
  # check_pointer_timeout() does.
  class FloatingBar
    HOVER_HIDE_TIMEOUT_INTERVAL = 100

    def initialize(on_stop: nil)
      @on_stop = on_stop
      @is_interactive = false
      @hover_timeout_id = nil
      @pointer = [-1, -1]
    end

    attr_accessor :is_interactive

    def build
      root.tap do |box|
        box.append(spinner)
        box.append(labels_box)
        box.append(stop_button)

        labels_box.tap do |labels|
          labels.append(primary_label)
          labels.append(details_label)
        end

        stop_button.signal_connect('clicked') do
          @on_stop&.call
        end

        box.signal_connect('notify::parent') do
          attach_motion_controller
        end
      end
    end

    def primary_label_text=(text)
      primary_label.label = text.to_s
      text
    end

    def details_label_text=(text)
      details_label.label = text.to_s
      text
    end

    def show_spinner=(show_spinner)
      spinner.visible = show_spinner
      show_spinner
    end

    def show_stop=(show_stop)
      stop_button.visible = show_stop
      show_stop
    end

    def root
      @root ||= Gtk::Box.new(:horizontal, 8).tap do |box|
        box.halign = :end
        box.valign = :end
        box.margin_top = 4
        box.margin_bottom = 4
        box.margin_start = 4
        box.margin_end = 4
        box.add_css_class('floating-bar')
      end
    end

    def spinner
      @spinner ||= Adwaita::Spinner.new.tap do |widget|
        widget.visible = false
        widget.set_size_request(16, 16)
        widget.margin_start = 8
      end
    end

    def labels_box
      @labels_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.hexpand = true
        box.margin_top = 2
        box.margin_bottom = 2
        box.margin_start = 8
        box.margin_end = 8
      end
    end

    def primary_label
      @primary_label ||= Gtk::Label.new.tap do |widget|
        widget.ellipsize = :middle
        widget.single_line_mode = true
      end
    end

    def details_label
      @details_label ||= Gtk::Label.new.tap do |widget|
        widget.single_line_mode = true
      end
    end

    def stop_button
      @stop_button ||= Gtk::Button.new.tap do |widget|
        widget.icon_name = 'process-stop-symbolic'
        widget.valign = :center
        widget.visible = false
        widget.tooltip_text = 'Stop'
        widget.add_css_class('circular')
        widget.add_css_class('flat')
      end
    end

    private

      # on_parent_changed(): the motion controller lives on the parent, in the
      # capture phase, so the bar sees the pointer before the view does.
      def attach_motion_controller
        root.parent.then do |parent|
          unless parent.nil? || @motion_parent == parent
            @motion_parent = parent
            parent.add_controller(motion_controller)
          end
        end
      end

      def motion_controller
        @motion_controller ||= Gtk::EventControllerMotion.new.tap do |controller|
          controller.propagation_phase = :capture
          controller.signal_connect('motion') do |_controller, x, y|
            on_motion(x, y)
          end
          controller.signal_connect('leave') do
            @pointer = [-1, -1]
          end
        end
      end

      def on_motion(x, y)
        @pointer = [x, y]
        unless @is_interactive || !root.visible? || @hover_timeout_id
          start_hover_timeout
        end
      end

      def start_hover_timeout
        bounds_in_parent.then do |bounds|
          if !bounds.nil? && contains?(bounds, @pointer)
            root.visible = false
            @hover_timeout_id = GLib::Timeout.add(HOVER_HIDE_TIMEOUT_INTERVAL) do
              check_pointer(bounds)
            end
          end
        end
      end

      def check_pointer(bounds)
        if contains?(bounds, @pointer)
          GLib::Source::CONTINUE
        else
          root.visible = true
          @hover_timeout_id = nil
          GLib::Source::REMOVE
        end
      end

      # gtk_widget_compute_bounds() returns a success flag beside the
      # rectangle, and the bindings hand both back as a pair.
      def bounds_in_parent
        root.compute_bounds(@motion_parent).then do |(computed, bounds)|
          if computed
            bounds
          end
        end
      rescue StandardError
        nil
      end

      def contains?(bounds, pointer)
        pointer.then do |(x, y)|
          x >= bounds.x && y >= bounds.y &&
            x <= (bounds.x + bounds.width) && y <= (bounds.y + bounds.height)
        end
      end
  end
end
