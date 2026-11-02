# frozen_string_literal: true

require 'adwaita'
require_relative 'filename_validator'

module Nautilus
  # RenameFilePopover renames one file in place.
  #
  # Ported from src/resources/ui/nautilus-rename-file-popover.blp and
  # nautilus-rename-file-popover.c: the title label, the entry, the feedback
  # revealer and the Rename button. The entry's selection covers the name
  # without its extension for a file, and the whole name for a folder, which
  # is what nautilus_rename_file_popover_show_for_file() sets up.
  class RenameFilePopover
    def initialize(on_accept: nil)
      @on_accept = on_accept
      @validator = FilenameValidator.new
    end

    attr_reader :validator

    def build
      popover.tap do |widget|
        widget.child = box

        box.tap do |container|
          container.append(title_label)
          container.append(name_entry)
          container.append(feedback_revealer)
          container.append(rename_button)
        end

        feedback_revealer.child = feedback_label

        name_entry.tap do |entry|
          entry.signal_connect('changed') do
            @validator.new_name = entry.text
            @validator.validate
          end
          entry.signal_connect('activate') { @validator.try_accept }
        end

        rename_button.signal_connect('clicked') { @validator.try_accept }

        widget.signal_connect('closed') { on_closed }

        @validator.on_state_changed { refresh_feedback }
        @validator.on_name_accepted { accept }
      end
    end

    # nautilus_rename_file_popover_show_for_file().
    def show_for(file, containing_directory, parent)
      @file = file
      @validator.containing_directory = containing_directory
      @validator.original_name = file.name
      @validator.target_is_folder = file.directory?
      title_label.label = title_for(file)
      name_entry.text = file.display_name
      select_name_without_extension(file)
      # One parent at a time: the popover follows the row it is renaming.
      popover.unparent
      popover.set_parent(parent)
      popover.popup
    end

    def popover = @popover ||= Gtk::Popover.new

    def box
      @box ||= Gtk::Box.new(:vertical, 0).tap do |container|
        container.margin_start = 18
        container.margin_end = 18
        container.margin_top = 18
        container.margin_bottom = 18
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.margin_bottom = 12
        label.add_css_class('title-2')
      end
    end

    def name_entry
      @name_entry ||= Gtk::Entry.new.tap do |entry|
        entry.margin_bottom = 12
      end
    end

    def feedback_revealer = @feedback_revealer ||= Gtk::Revealer.new

    def feedback_label
      @feedback_label ||= Gtk::Label.new.tap do |label|
        label.margin_bottom = 12
        label.max_width_chars = 0
        label.wrap = true
        label.xalign = 0
      end
    end

    def rename_button
      @rename_button ||= Gtk::Button.new.tap do |button|
        button.label = '_Rename'
        button.use_underline = true
        button.halign = :end
        button.add_css_class('suggested-action')
      end
    end

    private

      def title_for(file)
        if file.directory?
          'Rename Folder'
        else
          'Rename File'
        end
      end

      # A file's extension is left out of the selection, so typing replaces
      # the name and keeps the suffix.
      def select_name_without_extension(file)
        if file.directory?
          name_entry.select_region(0, -1)
        else
          name_entry.select_region(0, extension_start(file.display_name))
        end
      end

      def extension_start(name)
        ::File.extname(name).then do |extension|
          if extension.empty?
            -1
          else
            name.length - extension.length
          end
        end
      end

      def refresh_feedback
        feedback_label.label = @validator.feedback_text.to_s
        feedback_revealer.reveal_child = @validator.has_feedback?
        rename_button.sensitive = @validator.passed?
      end

      def accept
        @on_accept&.call(@file, @validator.stripped_name)
        popover.popdown
      end

      def on_closed
        @file = nil
      end
  end
end
