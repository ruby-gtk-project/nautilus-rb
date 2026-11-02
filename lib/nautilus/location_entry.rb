# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # LocationEntry is the editable path entry the toolbar swaps the pathbar for.
  #
  # Ported from src/nautilus-location-entry.c: an entry with a clear icon,
  # Tab completing the typed path against the folder it names, Escape
  # restoring the entry to the current location and Return opening what was
  # typed. Upstream completes on a worker thread through GtkEntryCompletion
  # with the common prefix dimmed; here the candidate list is read from the
  # typed directory and offered through the same GtkEntryCompletion, the
  # completion happening when the user asks for it rather than on an idle.
  class LocationEntry
    def initialize(on_open: nil, on_cancel: nil)
      @on_open = on_open
      @on_cancel = on_cancel
    end

    def build
      entry.tap do |widget|
        widget.completion = completion

        widget.signal_connect('changed') do
          update_completions_store
          update_clear_icon
        end

        widget.signal_connect('activate') do
          @on_open&.call(location_from_text)
        end

        widget.signal_connect('icon-release') do
          widget.text = ''
        end

        widget.add_controller(key_controller)
      end
    end

    # Puts the current location in the entry and selects it, the way
    # nautilus_location_entry_set_location() does before the entry is shown.
    def location=(location)
      entry.text = text_for(location)
      entry.select_region(0, -1)
      location
    end

    def text = entry.text

    def entry
      @entry ||= Gtk::Entry.new.tap do |widget|
        widget.hexpand = true
        widget.activates_default = false
        widget.input_hints = :no_spellcheck
        widget.set_icon_from_icon_name(:secondary, nil)
        widget.set_icon_tooltip_text(:secondary, 'Clear Entry')
      end
    end

    def completion
      @completion ||= Gtk::EntryCompletion.new.tap do |widget|
        widget.model = completions_store
        widget.text_column = 0
        widget.inline_completion = true
        widget.popup_completion = true
        widget.pack_start(completion_cell, true)
        widget.add_attribute(completion_cell, 'text', 0)
      end
    end

    def completions_store = @completions_store ||= Gtk::ListStore.new(String)

    def completion_cell = @completion_cell ||= Gtk::CellRendererText.new

    private

      def key_controller
        @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
          controller.signal_connect('key-pressed') do |_controller, keyval, _code, _state|
            on_key_pressed(keyval)
          end
        end
      end

      def on_key_pressed(keyval)
        case keyval
        when Gdk::Keyval::KEY_Tab
          insert_prefix
          true
        when Gdk::Keyval::KEY_Escape
          @on_cancel&.call
          true
        else
          false
        end
      end

      # nautilus_location_entry_insert_prefix(): Tab fills in as much of the
      # candidates' common prefix as is unambiguous.
      def insert_prefix
        candidates.then do |names|
          common_prefix(names).then do |prefix|
            unless prefix.nil? || prefix == entry.text
              entry.text = prefix
              entry.position = -1
            end
          end
        end
      end

      def common_prefix(names)
        if names.empty?
          nil
        else
          names.reduce do |prefix, name|
            prefix.each_char.zip(name.each_char).take_while { |(a, b)| a == b }.map(&:first).join
          end
        end
      end

      # update_completions_store(): completions are only offered while the
      # cursor is at the end of the text.
      def update_completions_store
        completions_store.clear
        if entry.position.negative? || entry.position == entry.text.length
          candidates.each do |candidate|
            completions_store.append[0] = candidate
          end
        end
      end

      # completer_get_completions_thread(): the children of the folder the
      # typed path names, whose basenames start with what was typed after the
      # last separator.
      def candidates
        typed_directory.then do |(directory, prefix)|
          if directory.nil?
            []
          else
            children_of(directory, prefix)
          end
        end
      end

      def typed_directory
        entry.text.to_s.then do |text|
          if text.empty? || !text.start_with?('/', '~')
            [nil, nil]
          else
            split_typed_path(::File.expand_path(text.sub(/\A~/, Dir.home)))
              .then { |(parent, prefix)| [parent, trailing_prefix(text, prefix)] }
          end
        end
      end

      # A path ending in a separator is a complete directory name, so the
      # prefix is empty and every child matches.
      def split_typed_path(path)
        if path == '/'
          ['/', '']
        else
          [::File.dirname(path), ::File.basename(path)]
        end
      end

      def trailing_prefix(text, prefix)
        if text.end_with?('/')
          ''
        else
          prefix
        end
      end

      def children_of(directory, prefix)
        Gio::File.new_for_path(directory)
                 .enumerate_children('standard::name,standard::type', :none, nil).then do |enumerator|
          names = []
          while (info = enumerator.next_file(nil))
            names << ::File.join(directory, suffixed(info))
          end
          enumerator.close
          names.select { |name| ::File.basename(name).start_with?(prefix.to_s) }.sort
        end
      rescue GLib::Error
        []
      end

      # A directory candidate carries its trailing separator, so completing
      # onto it goes straight on into the folder.
      def suffixed(info)
        if info.file_type == :directory
          "#{info.name}/"
        else
          info.name
        end
      end

      def update_clear_icon
        if entry.text.to_s.empty?
          entry.set_icon_from_icon_name(:secondary, nil)
        else
          entry.set_icon_from_icon_name(:secondary, 'edit-clear-symbolic')
        end
      end

      def text_for(location)
        if location.nil?
          ''
        else
          location.path || location.uri
        end
      end

      def location_from_text
        entry.text.to_s.then do |text|
          if text.start_with?('/', '~')
            Gio::File.new_for_path(::File.expand_path(text.sub(/\A~/, Dir.home)))
          else
            Gio::File.new_for_uri(text)
          end
        end
      end
  end
end
