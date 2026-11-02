# frozen_string_literal: true

require 'adwaita'
require_relative 'view_cell'

module Nautilus
  # LabelCell is the cell every column other than name and starred uses.
  #
  # Ported from src/nautilus-label-cell.c: one label showing the file
  # attribute the column names, aligned the way the column definition says.
  class LabelCell < ViewCell
    def initialize(column, **callbacks)
      super(**callbacks)
      @column = column
    end

    attr_reader :column

    def build
      super.tap do |widget|
        widget.orientation = :horizontal
        widget.append(label)
      end
    end

    def label
      @label ||= Gtk::Label.new.tap do |widget|
        widget.ellipsize = :end
        widget.hexpand = true
        widget.xalign = @column.xalign
        widget.add_css_class('dim-label')
        if numeric?
          widget.add_css_class('numeric')
        end
      end
    end

    private

      # The date and size columns are right-aligned and use the tabular
      # figures the `numeric` class selects.
      def numeric? = @column.xalign == 1.0

      def show(item)
        label.label = item.attribute(@column.attribute)
      end
  end
end
