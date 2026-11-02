# frozen_string_literal: true

require 'adwaita'
require_relative 'ui_utilities'

module Nautilus
  # ViewControls is the split button that switches the view, with the view
  # options menu on its dropdown.
  #
  # Ported from src/resources/ui/nautilus-view-controls.blp,
  # nautilus-view-controls.c and src/resources/menu/nautilus-toolbar-view-menu.ui.
  # The menu's five sections are upstream's: the inline Icon Size buttons
  # filling the `zoom-out` and `zoom-in` custom slots, the Sort section the
  # view fills, Show Hidden Files, Visible Columns… and Captions….
  class ViewControls
    # sort_section from nautilus-toolbar-view-menu.ui: nine items, all
    # `view.sort`, each targeting an attribute and a reversed flag.
    SORT_SECTION = [
      { label: '_A-Z', action: 'view.sort', target: "('name', false)", hidden_when: 'action-disabled' },
      { label: '_Z-A', action: 'view.sort', target: "('name', true)", hidden_when: 'action-disabled' },
      {
        label:       'Last _Modified',
        action:      'view.sort',
        target:      "('date_modified', true)",
        hidden_when: 'action-disabled',
      },
      {
        label:       '_First Modified',
        action:      'view.sort',
        target:      "('date_modified', false)",
        hidden_when: 'action-disabled',
      },
      { label: '_Size', action: 'view.sort', target: "('size', true)", hidden_when: 'action-disabled' },
      { label: '_Type', action: 'view.sort', target: "('type', false)", hidden_when: 'action-disabled' },
      {
        label:       'Last _Trashed',
        action:      'view.sort',
        target:      "('trashed_on', true)",
        hidden_when: 'action-disabled',
        item_name:   'last_trashed',
      },
      {
        label:       'Recency',
        action:      'view.sort',
        target:      "('recency', true)",
        hidden_when: 'action-disabled',
        item_name:   'recency',
      },
      {
        label:       'Relevance',
        action:      'view.sort',
        target:      "('search_relevance', true)",
        hidden_when: 'action-disabled',
        item_name:   'relevance',
      },
    ].freeze

    def initialize(window_slot: nil)
      @window_slot = window_slot
    end

    attr_reader :window_slot

    def window_slot=(window_slot)
      @window_slot = window_slot
      refresh
    end

    def build
      root.tap do |bin|
        bin.child = split_button

        split_button.popover = popover

        popover.tap do |menu|
          menu.add_child(zoom_out_button, 'zoom-out')
          menu.add_child(zoom_in_button, 'zoom-in')
        end

        refresh
      end
    end

    # The icon and tooltip follow the slot, which is where the blueprint
    # binds them from.
    def refresh
      unless @window_slot.nil?
        split_button.icon_name = @window_slot.view_icon_name
        split_button.tooltip_text = @window_slot.view_tooltip
      end
    end

    def root = @root ||= Adwaita::Bin.new

    def split_button
      @split_button ||= Adwaita::SplitButton.new.tap do |button|
        button.halign = :center
        button.valign = :center
        button.dropdown_tooltip = 'View Options'
        button.action_name = 'slot.files-view-mode-toggle'
      end
    end

    def popover
      @popover ||= Gtk::PopoverMenu.new(view_menu)
    end

    def view_menu = @view_menu ||= UiUtilities.build_menu(view_menu_description)

    def view_menu_description
      [
        {
          label:        'Icon Size',
          display_hint: 'inline-buttons',
          section:      [{ custom: 'zoom-out' }, { custom: 'zoom-in' }],
        },
        { label: 'Sort', section: SORT_SECTION },
        {
          section: [
            { label: 'Show _Hidden Files', action: 'view.show-hidden-files', accel: '<control>h' },
          ],
        },
        {
          section: [
            { label: '_Visible Columns…', action: 'view.visible-columns', hidden_when: 'action-disabled' },
          ],
        },
        {
          section: [
            { label: 'Captions…', action: 'view.visible-captions', hidden_when: 'action-disabled' },
          ],
        },
      ]
    end

    def zoom_out_button
      @zoom_out_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'zoom-out-symbolic'
        button.action_name = 'view.zoom-out'
        button.tooltip_text = 'Zoom Out'
        button.add_css_class('flat')
      end
    end

    def zoom_in_button
      @zoom_in_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'zoom-in-symbolic'
        button.action_name = 'view.zoom-in'
        button.tooltip_text = 'Zoom In'
        button.add_css_class('flat')
      end
    end
  end
end
