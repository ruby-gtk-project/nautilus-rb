# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # A direct port of src/resources/ui/shortcuts-dialog.blp, which has no
  # backing .c file: eighteen sections and fifty-six items. The seven
  # sections upstream titles are titled here; the rest continue the previous
  # one, which is how the blueprint leaves them. An item whose accelerator
  # comes from an action carries that action's accelerator, so the two forms
  # the blueprint uses — `accelerator:` and `action-name:` — are both kept.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    # [title, items], where an item is [title, accelerator] or
    # [title, {action: 'win.undo'}].
    SECTIONS = [
      ['Actions', [
        ['Open', 'Return <Primary>O'],
        ['Open in New Tab', '<Primary>Return'],
        ['Open in New Window', '<shift>Return'],
        ['Open Item Location (Search and Recent Only)', '<alt><Primary>O'],
        ['Open With Default App', '<Primary>O <alt>Down'],
        ['Open Current Directory in Console', '<Primary>period'],
        ['Open Current Folder Menu', { action: 'win.current-location-menu' }],
        ['Open Context Menu', '<Shift>F10'],
      ]
],
      [nil, [['Create Folder', '<Primary><shift>N']]],
      [nil, [
        ['Cut', '<Primary>X'],
        ['Copy', '<Primary>C'],
        ['Paste', '<Primary>V'],
      ]
],
      [nil, [['Rename', 'F2']]],
      [nil, [
        ['Undo', { action: 'win.undo' }],
        ['Redo', { action: 'win.redo' }],
      ]
],
      [nil, [
        ['Move to Trash', 'Delete'],
        ['Delete Permanently', '<shift>Delete'],
      ]
],
      [nil, [
        ['Create Link to Copied Item', '<Primary>M'],
        ['Create Link to Selected Item', '<Primary><shift>M'],
      ]
],
      [nil, [['Show Item Properties', '<Primary>I <alt>Return']]],
      [nil, [['Bookmark Current Location', '<Primary>D']]],
      ['View', [
        ['Zoom In', '<Primary>plus'],
        ['Zoom Out', '<Primary>minus'],
        ['Reset Zoom', '<Primary>0'],
      ]
],
      [nil, [
        ['List View', '<Primary>1'],
        ['Grid View', '<Primary>2'],
        ['Refresh View', 'F5 <Primary>R'],
      ]
],
      [nil, [
        ['Expand Folder', 'Right'],
        ['Collapse Folder', 'Left'],
      ]
],
      [nil, [
        ['Show/Hide Hidden Files', '<Primary>H'],
        ['Show/Hide Sidebar', { action: 'win.toggle-sidebar' }],
      ]
],
      ['Select', [
        ['Select All', '<Primary>A'],
        ['Invert Selection', '<shift><Primary>I'],
        ['Select Items Matching', '<Primary>S'],
      ]
],
      ['Navigation', [
        ['Go Back', '<alt>Left'],
        ['Go Forward', '<alt>Right'],
        ['Go Up', '<alt>Up'],
        ['Go Down', '<alt>Down'],
        ['Go to Home Folder', '<alt>Home'],
      ]
],
      [nil, [
        ['Enter Location', '<Primary>L'],
        ['Location Bar With Root Location', 'slash'],
        ['Location Bar With Home Location', 'asciitilde'],
      ]
],
      ['Search', [
        ['Search Everywhere', '<Primary><Shift>F'],
        ['Search Current Folder', '<Primary>F'],
      ]
],
      ['Windows & Tabs', [
        ['New Window', { action: 'app.clone-window' }],
        ['New Tab', { action: 'win.new-tab' }],
        ['Close Window or Tab', { action: 'win.close-current-view' }],
        ['Show All Tabs', { action: 'win.open-tab-overview' }],
        ['Restore Closed Tab', { action: 'win.restore-tab' }],
      ]
],
      [nil, [
        ['Go to Previous Tab', '<Primary>Page_Up'],
        ['Go to Next Tab', '<Primary>Page_Down'],
        ['Open Tab', '<alt>0...8'],
      ]
],
      [nil, [
        ['Move Tab Left', { action: 'win.tab-move-left' }],
        ['Move Tab Right', { action: 'win.tab-move-right' }],
      ]
],
      ['App', [
        ['Show Preferences', { action: 'app.preferences' }],
        ['Shortcuts', { action: 'app.shortcuts' }],
        ['Show Help', { action: 'app.help' }],
        ['Quit', { action: 'app.quit' }],
      ]
],
    ].freeze

    def initialize
      super()
      self.title = 'Keyboard Shortcuts'
    end

    def build
      tap do |dialog|
        SECTIONS.each do |(title, items)|
          dialog.add(section(title, items))
        end
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |section|
          unless title.nil?
            section.title = title
          end
          items.each { |(item_title, accelerator)| section.add(item(item_title, accelerator)) }
        end
      end

      # Positional, not keyword, arguments — even though the error a
      # no-argument new raises advertises the signatures as
      # "title: utf8, accelerator: utf8". An item taking its accelerator from
      # an action is built with no accelerator and told the action name.
      def item(title, accelerator)
        if accelerator.is_a?(Hash)
          Adwaita::ShortcutsItem.new(title, '').tap do |shortcut|
            shortcut.action_name = accelerator.fetch(:action)
          end
        else
          Adwaita::ShortcutsItem.new(title, accelerator)
        end
      end
  end
end
