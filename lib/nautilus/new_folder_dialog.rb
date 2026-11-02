# frozen_string_literal: true

require 'adwaita'
require_relative 'filename_validator'

module Nautilus
  # NewFolderDialog asks for the name of a folder to create.
  #
  # Ported from src/resources/ui/nautilus-new-folder-dialog.blp and
  # nautilus-new-folder-dialog.c: the name row, the feedback revealer the
  # validator drives, and the pill Create button which is sensitive only
  # while the validator has passed.
  class NewFolderDialog
    def initialize(containing_directory:, with_selection: false, on_accept: nil)
      @with_selection = with_selection
      @on_accept = on_accept
      @validator = FilenameValidator.new(
        containing_directory: containing_directory,
        target_is_folder:     true,
      )
    end

    attr_reader :validator

    def build
      dialog.tap do |window|
        window.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(Adwaita::HeaderBar.new)
          view.content = page
        end

        page.add(group)

        group.tap do |preferences|
          preferences.add(name_entry)
          preferences.add(feedback_revealer)
          preferences.add(create_button)
        end

        feedback_revealer.child = feedback_label

        name_entry.tap do |row|
          row.signal_connect('changed') do
            @validator.new_name = row.text
            @validator.validate
          end
          row.signal_connect('entry-activated') { @validator.try_accept }
        end

        create_button.signal_connect('clicked') { @validator.try_accept }

        @validator.on_state_changed { refresh_feedback }
        @validator.on_name_accepted { accept }

        refresh_feedback
      end
    end

    def present(parent)
      dialog.present(parent)
      name_entry.grab_focus
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |window|
        window.title = 'New Folder'
        window.content_width = 450
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def page = @page ||= Adwaita::PreferencesPage.new

    def group = @group ||= Adwaita::PreferencesGroup.new

    def name_entry
      @name_entry ||= Adwaita::EntryRow.new.tap do |row|
        row.title = '_Folder Name'
        row.use_underline = true
      end
    end

    def feedback_revealer
      @feedback_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :crossfade
      end
    end

    def feedback_label
      @feedback_label ||= Gtk::Label.new.tap do |label|
        label.margin_top = 6
        label.xalign = 0
        label.add_css_class('warning')
        label.add_css_class('caption')
      end
    end

    def create_button
      @create_button ||= Gtk::Button.new.tap do |button|
        button.label = '_Create'
        button.use_underline = true
        button.margin_top = 6
        button.halign = :center
        button.add_css_class('pill')
        button.add_css_class('suggested-action')
      end
    end

    private

      def refresh_feedback
        feedback_label.label = @validator.feedback_text.to_s
        feedback_revealer.reveal_child = @validator.has_feedback?
        create_button.sensitive = @validator.passed?
      end

      def accept
        @on_accept&.call(@validator.stripped_name, @with_selection)
        dialog.close
      end
  end
end
