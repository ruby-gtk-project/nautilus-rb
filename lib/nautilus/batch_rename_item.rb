# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # BatchRenameItem is one row of the batch-rename dialog's preview list.
  #
  # Ported from src/nautilus-batch-rename-item.c: the name before the rename,
  # the name after it, and whether the name after it collides with another
  # row's — which is what puts the `.conflict-row` class on the row. Setting
  # any of the three tells the dialog, which is how upstream's property
  # notifications reach the preview.
  class BatchRenameItem < GLib::Object
    type_register

    def initialize(name_before, name_after, on_changed: nil)
      super()
      @name_before = name_before
      @name_after = name_after
      @has_conflict = false
      @on_changed = on_changed
    end

    attr_reader :name_before, :name_after

    def has_conflict? = @has_conflict

    def name_before=(name)
      unless @name_before == name
        @name_before = name
        changed
      end
    end

    def name_after=(name)
      unless @name_after == name
        @name_after = name
        changed
      end
    end

    def has_conflict=(has_conflict)
      unless @has_conflict == has_conflict
        @has_conflict = has_conflict
        changed
      end
    end

    private

      def changed
        @on_changed&.call(self)
      end
  end
end
