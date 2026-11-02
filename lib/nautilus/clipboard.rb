# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # Clipboard carries cut and copied files between windows.
  #
  # Ported from src/nautilus-clipboard.c. The text form is upstream's and is
  # what makes the clipboard interoperable with a running nautilus: the first
  # line is literally "cut" or "copy" and every line after it is a URI.
  # Upstream also registers a boxed GValue type for the same contents; the
  # Ruby bindings cannot register one, so the text form is the only one this
  # reads and writes, which is the form nautilus falls back to anyway.
  class Clipboard
    CUT = 'cut'
    COPY = 'copy'

    def self.for_display(display = Gdk::Display.default) = new(display.clipboard)

    def initialize(gdk_clipboard)
      @clipboard = gdk_clipboard
    end

    attr_reader :clipboard

    # nautilus_clipboard_prepare(): what view.cut puts on the clipboard.
    def cut(files)
      write(CUT, files)
    end

    # What view.copy puts on the clipboard.
    def copy(files)
      write(COPY, files)
    end

    # nautilus_clipboard_from_string(): reads the clipboard and hands the
    # caller the locations and whether they were cut. Anything that does not
    # begin with "cut" or "copy" is not ours, and yields nothing.
    def read(&on_read)
      @clipboard.read_text_async(nil) do |_clipboard, result|
        on_read.call(parse(finish_read(result)))
      end
    end

    def parse(text)
      text.to_s.split("\n").then do |lines|
        if [CUT, COPY].include?(lines.first)
          {
            cut:       lines.first == CUT,
            locations: lines.drop(1).map { |uri| Gio::File.new_for_uri(uri) },
          }
        end
      end
    end

    def to_string(action, files)
      [action, *files.map(&:uri)].join("\n")
    end

    private

      def write(action, files)
        @clipboard.set(to_string(action, files))
      end

      def finish_read(result)
        @clipboard.read_text_finish(result)
      rescue GLib::Error
        nil
      end
  end
end
