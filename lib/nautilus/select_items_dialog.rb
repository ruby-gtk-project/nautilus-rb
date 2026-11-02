# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # SelectItemsDialog selects every item matching a pattern.
  #
  # Ported from src/resources/ui/nautilus-files-view-select-items.blp: the
  # heading, the pattern entry, the example line and the Cancel/Select pair
  # in the header bar, with Select as the default widget so Return in the
  # entry accepts.
  class SelectItemsDialog
    EXAMPLE = 'Examples: "*.png", "file\?", "*file*"'

    def initialize(on_select: nil)
      @on_select = on_select
    end

    def build
      dialog.tap do |window|
        window.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = box
        end

        header_bar.tap do |header|
          header.pack_start(cancel_button)
          header.pack_end(select_button)
        end

        box.tap do |container|
          container.append(heading_label)
          container.append(pattern_entry)
          container.append(example_label)
        end

        cancel_button.signal_connect('clicked') { window.close }
        select_button.signal_connect('clicked') { accept }
        pattern_entry.signal_connect('activate') { accept }

        window.default_widget = select_button
      end
    end

    def present(parent)
      dialog.present(parent)
      pattern_entry.grab_focus
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |window|
        window.title = 'Select Items Matching'
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |header|
        header.show_start_title_buttons = false
        header.show_end_title_buttons = false
      end
    end

    def box
      @box ||= Gtk::Box.new(:vertical, 6).tap do |container|
        container.margin_top = 18
        container.margin_bottom = 18
        container.margin_start = 18
        container.margin_end = 18
      end
    end

    def heading_label
      @heading_label ||= Gtk::Label.new('Pattern').tap do |label|
        label.halign = :start
        label.add_css_class('heading')
      end
    end

    def pattern_entry
      @pattern_entry ||= Gtk::Entry.new.tap do |entry|
        entry.hexpand = true
        entry.activates_default = true
        entry.input_hints = :no_spellcheck
      end
    end

    def example_label
      @example_label ||= Gtk::Label.new(EXAMPLE).tap do |label|
        label.halign = :start
      end
    end

    def cancel_button
      @cancel_button ||= Gtk::Button.new.tap do |button|
        button.label = '_Cancel'
        button.use_underline = true
        button.can_shrink = true
      end
    end

    def select_button
      @select_button ||= Gtk::Button.new.tap do |button|
        button.label = '_Select'
        button.use_underline = true
        button.can_shrink = true
        button.add_css_class('suggested-action')
      end
    end

    private

      def accept
        @on_select&.call(pattern_entry.text)
        dialog.close
      end
  end
end
