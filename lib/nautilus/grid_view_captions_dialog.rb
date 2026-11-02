# frozen_string_literal: true

require 'adwaita'
require_relative 'global_preferences'
require_relative 'column_utilities'

module Nautilus
  # GridViewCaptionsDialog picks the three captions shown under grid icons.
  #
  # Ported from src/resources/ui/nautilus-grid-view-captions-dialog.blp and
  # nautilus-grid-view-captions-dialog.c: three combo rows, each listing
  # "None" plus the attributes a caption can show, writing straight into the
  # icon-view schema's `captions` key.
  class GridViewCaptionsDialog
    # The attributes offered, in the order upstream lists them, each with the
    # label the combo row shows.
    CAPTION_ATTRIBUTES = [
      ['none', 'None'],
      ['size', 'Size'],
      ['type', 'Type'],
      ['date_modified', 'Modified'],
      ['date_accessed', 'Accessed'],
      ['date_created', 'Created'],
      ['detailed_type', 'Detailed Type'],
      ['owner', 'Owner'],
      ['group', 'Group'],
      ['permissions', 'Permissions'],
    ].freeze

    TITLES = ['Fi_rst', 'Seco_nd', 'T_hird'].freeze

    DESCRIPTION = 'Add information to be displayed beneath file and folder names. ' \
                  'More information will appear when zooming closer.'

    def initialize(on_changed: nil)
      @on_changed = on_changed
    end

    def build
      dialog.tap do |window|
        window.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = page
        end

        page.add(group)

        combo_rows.each_with_index do |row, index|
          group.add(row)
          row.signal_connect('notify::selected') do
            write_captions
          end
          row.selected = selected_index(index)
        end
      end
    end

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |window|
        window.width_request = 360
        window.height_request = 340
        window.content_width = 600
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |header|
        header.title_widget = Adwaita::WindowTitle.new('Grid View Captions', '')
      end
    end

    def page = @page ||= Adwaita::PreferencesPage.new

    def group
      @group ||= Adwaita::PreferencesGroup.new.tap do |preferences|
        preferences.description = DESCRIPTION
      end
    end

    def combo_rows
      @combo_rows ||= TITLES.map do |title|
        Adwaita::ComboRow.new.tap do |row|
          row.title = title
          row.use_underline = true
          row.use_markup = false
          row.model = Gtk::StringList.new(CAPTION_ATTRIBUTES.map(&:last))
        end
      end
    end

    private

      def captions = GlobalPreferences.instance.icon_view['captions']

      def selected_index(position)
        CAPTION_ATTRIBUTES.map(&:first).index(captions.fetch(position, 'none')).to_i
      end

      def write_captions
        combo_rows.map { |row| CAPTION_ATTRIBUTES.fetch(row.selected).first }.then do |chosen|
          GlobalPreferences.instance.icon_view['captions'] = chosen
          @on_changed&.call(chosen)
        end
      end
  end
end
