# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # MinimalCell is the title/subtitle/paintable triple the file-type list
  # binds its rows to.
  #
  # Ported from src/nautilus-minimal-cell.c, which is a GObject holding
  # nothing but those three values. It is a GLib::Object here because it goes
  # into a Gio::ListStore, and only a GObject can.
  class MinimalCell < GLib::Object
    type_register

    def initialize(title, subtitle, paintable = nil)
      super()
      @title = title
      @subtitle = subtitle
      @paintable = paintable
    end

    attr_reader :title, :subtitle, :paintable
  end
end
