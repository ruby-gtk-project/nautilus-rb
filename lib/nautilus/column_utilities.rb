# frozen_string_literal: true

module Nautilus
  # ColumnUtilities carries the list-view column definitions.
  #
  # Ported from src/nautilus-column-utilities.c. Each Column is upstream's
  # NautilusColumn object: a name, the file attribute it reads, the label the
  # header and the column chooser show, a description, the sort order a click
  # on its header starts from, and the alignment of its cells. The extension
  # columns upstream collects from NautilusColumnProvider have no counterpart
  # here, since there is no Ruby plugin ABI to collect them from.
  module ColumnUtilities
    # One column definition. `visible` and `order` are not part of the
    # definition; they come from the list-view schema.
    Column = Struct.new(
      :name,
      :attribute,
      :label,
      :description,
      :default_sort_order,
      :xalign,
      keyword_init: true,
    ) do
      def descending? = default_sort_order == :descending
    end

    DEFAULT_COLUMN_ORDER = %w[
      name size type owner group permissions detailed_type
      date_modified date_accessed date_created recency starred
    ].freeze

    DEFAULT_COLUMNS_FOR_RECENT = %w[name size recency].freeze
    DEFAULT_COLUMNS_FOR_TRASH = %w[name size trashed_on].freeze

    module_function

    # get_builtin_columns(), in the order upstream appends them.
    def builtin_columns
      @builtin_columns ||= [
        column('name', 'Name', 'The name and icon of the file.'),
        column('size', 'Size', 'The size of the file.'),
        column('type', 'Type', 'The type of the file.'),
        date_column('date_modified', 'Modified', 'The date the file was modified.'),
        column('detailed_type', 'Detailed Type', 'The detailed type of the file.'),
        date_column('date_accessed', 'Accessed', 'The date the file was accessed.'),
        date_column('date_created', 'Created', 'The date the file was created.'),
        column('owner', 'Owner', 'The owner of the file.'),
        column('group', 'Group', 'The group of the file.'),
        column('permissions', 'Permissions', 'The permissions of the file.'),
        date_column('recency', 'Recency', 'The date the file was accessed by the user.'),
        starred_column,
      ].freeze
    end

    # get_trash_columns(): only shown while the view is inside the trash.
    def trash_columns
      @trash_columns ||= [
        Column.new(
          name:               'trashed_on',
          attribute:          'trashed_on',
          label:              'Trashed On',
          description:        'Date when file was moved to the Trash',
          default_sort_order: :ascending,
          xalign:             1.0,
        ),
        column(
          'trash_orig_path',
          'Original Location',
          'Original location of file before moved to the Trash',
        ),
      ].freeze
    end

    # get_search_columns(): only shown while the view shows search results.
    def search_columns
      @search_columns ||= [
        column('search_relevance', 'Relevance', 'Relevance rank for search'),
      ].freeze
    end

    def common_columns = builtin_columns

    def all_columns = common_columns + trash_columns + search_columns

    # nautilus_get_columns_for_file(): the trash columns join in only for a
    # file inside the trash.
    def columns_for_file(file)
      if file.respond_to?(:in_trash?) && file.in_trash?
        common_columns + trash_columns
      else
        common_columns
      end
    end

    def column_by_name(name)
      all_columns.find { |column| column.name == name.to_s }
    end

    # nautilus_sort_columns(): orders the definitions by a stored column
    # order, with anything the order does not mention left at the end.
    def sort_columns(columns, column_order)
      columns.sort_by do |column|
        column_order.index(column.name).then do |index|
          if index.nil?
            columns.size + columns.index(column)
          else
            index
          end
        end
      end
    end

    # The default visible columns for a location, matching
    # default_columns_for_recent / default_columns_for_trash.
    def default_visible_columns(location_kind, stored_default)
      case location_kind
      when :recent then DEFAULT_COLUMNS_FOR_RECENT
      when :trash then DEFAULT_COLUMNS_FOR_TRASH
      else stored_default
      end
    end

    def column(name, label, description)
      Column.new(
        name:               name,
        attribute:          name,
        label:              label,
        description:        description,
        default_sort_order: :ascending,
        xalign:             0.0,
      )
    end

    def date_column(name, label, description)
      Column.new(
        name:               name,
        attribute:          name,
        label:              label,
        description:        description,
        default_sort_order: :descending,
        xalign:             1.0,
      )
    end

    # The starred column's header is deliberately blank upstream: the column
    # is a star toggle, and its label would crowd the header row.
    def starred_column
      Column.new(
        name:               'starred',
        attribute:          'starred',
        label:              '',
        description:        'Shows if file is starred.',
        default_sort_order: :descending,
        xalign:             0.5,
      )
    end
  end
end
