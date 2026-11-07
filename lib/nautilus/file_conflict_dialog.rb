# frozen_string_literal: true

require 'adwaita'
require_relative 'image'
require_relative 'dialog_utilities'

module Nautilus
  # FileConflictDialog asks what to do when a copy/move destination already
  # has a file with that name: replace it, rename the incoming one, skip it,
  # or cancel the whole operation.
  #
  # Ported from src/nautilus-file-conflict-dialog.c and its .blp: the
  # primary/secondary message, the two icon+label rows for the source and
  # destination files, an Expander revealing a rename entry (whose Rename
  # button only enables once the entry differs from both empty and the
  # original name) with a Reset button restoring the suggested name, and the
  # "apply to all" checkbox the expander's sensitivity tracks.
  class FileConflictDialog
    RESPONSE_CANCEL = :cancel
    RESPONSE_SKIP = :skip
    RESPONSE_RENAME = :rename
    RESPONSE_REPLACE = :replace

    def initialize(parent: nil)
      @parent = parent
      @response = RESPONSE_CANCEL
      @conflict_name = ''
      @suggested_name = ''
      @activation_timeout_id = nil
    end

    attr_reader :response

    def build
      dialog.tap do |window|
        window.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box
        end

        header_bar.tap do |bar|
          bar.pack_start(cancel_button)
          bar.pack_end(skip_button)
          bar.pack_end(rename_button)
          bar.pack_end(replace_button)
        end

        cancel_button.signal_connect('clicked') { respond(RESPONSE_CANCEL) }
        skip_button.signal_connect('clicked') { respond(RESPONSE_SKIP) }
        rename_button.signal_connect('clicked') { respond(RESPONSE_RENAME) }
        replace_button.signal_connect('clicked') { respond(RESPONSE_REPLACE) }

        content_box.tap do |box|
          box.append(primary_label)
          box.append(secondary_label)
          box.append(files_box)
          box.append(checkbox)
        end

        files_box.tap do |box|
          box.append(dest_row)
          box.append(src_row)
          box.append(expander)
        end

        dest_row.append(dest_icon.build)
        dest_row.append(dest_label)

        src_row.append(src_icon.build)
        src_row.append(src_label)

        expander.tap do |widget|
          widget.child = expander_box
          widget.signal_connect('notify::expanded') { on_expanded_notify }
        end

        expander_box.tap do |box|
          box.append(entry)
          box.append(reset_button)
        end

        entry.signal_connect('changed') { refresh_rename_sensitivity }
        reset_button.signal_connect('clicked') { reset_name }

        checkbox.signal_connect('toggled') { expander.sensitive = !checkbox.active? }

        window.add_controller(escape_key_controller)
      end
    end

    def present
      dialog.present
    end

    def set_text(primary, secondary)
      primary_label.label = primary.to_s
      secondary_label.label = secondary.to_s
    end

    def set_images(destination_file, source_file)
      dest_icon.file = destination_file
      src_icon.file = source_file
    end

    def set_file_labels(destination_label, source_label)
      dest_label.use_markup = true
      dest_label.label = destination_label.to_s
      src_label.use_markup = true
      src_label.label = source_label.to_s
    end

    def conflict_name=(name)
      @conflict_name = name.to_s
      name
    end

    def suggested_name=(name)
      @suggested_name = name.to_s
      entry.text = @suggested_name
      name
    end

    def replace_button_label=(label)
      replace_button.label = label
      label
    end

    def disable_skip
      skip_button.visible = false
    end

    def disable_replace
      replace_button.sensitive = false
    end

    def disable_apply_to_all
      checkbox.visible = false
    end

    def new_name = entry.text

    def apply_to_all? = checkbox.active?

    def delay_buttons_activation
      [cancel_button, skip_button, rename_button, replace_button, expander].each { |widget| widget.sensitive = false }
      @activation_timeout_id ||= GLib::Timeout.add_seconds(DialogUtilities::BUTTON_ACTIVATION_DELAY_IN_SECONDS) do
        [cancel_button, skip_button, rename_button, replace_button, expander].each { |widget| widget.sensitive = true }
        @activation_timeout_id = nil
        GLib::Source::REMOVE
      end
    end

    def dialog
      @dialog ||= Adwaita::Window.new.tap do |window|
        window.modal = true
        window.resizable = false
        unless @parent.nil?
          window.transient_for = @parent
        end
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_start_title_buttons = false
        bar.show_end_title_buttons = false
      end
    end

    def cancel_button
      @cancel_button ||= Gtk::Button.new.tap do |button|
        button.label = '_Cancel'
        button.use_underline = true
      end
    end

    def skip_button
      @skip_button ||= Gtk::Button.new.tap do |button|
        button.label = '_Skip'
        button.use_underline = true
      end
    end

    def rename_button
      @rename_button ||= Gtk::Button.new.tap do |button|
        button.visible = false
        button.label = '_Rename'
        button.use_underline = true
        button.add_css_class('suggested-action')
      end
    end

    def replace_button
      @replace_button ||= Gtk::Button.new.tap do |button|
        button.label = '_Replace'
        button.use_underline = true
        button.add_css_class('suggested-action')
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.margin_top = 18
        box.margin_bottom = 18
        box.margin_start = 18
        box.margin_end = 18
      end
    end

    def primary_label
      @primary_label ||= Gtk::Label.new.tap do |label|
        label.justify = :center
        label.halign = :center
        label.max_width_chars = 50
        label.wrap = true
        label.wrap_mode = :word_char
        label.add_css_class('title-2')
      end
    end

    def secondary_label
      @secondary_label ||= Gtk::Label.new.tap do |label|
        label.justify = :center
        label.halign = :center
        label.max_width_chars = 50
        label.wrap = true
        label.wrap_mode = :word_char
      end
    end

    def files_box
      @files_box ||= Gtk::Box.new(:vertical, 12).tap { |box| box.halign = :start }
    end

    def dest_row = @dest_row ||= Gtk::Box.new(:horizontal, 12)

    def src_row = @src_row ||= Gtk::Box.new(:horizontal, 12)

    def dest_icon = @dest_icon ||= Image.new(pixel_size: 48)

    def src_icon = @src_icon ||= Image.new(pixel_size: 48)

    def dest_label = @dest_label ||= Gtk::Label.new

    def src_label = @src_label ||= Gtk::Label.new

    def expander
      @expander ||= Gtk::Expander.new.tap do |widget|
        widget.label = 'Select a _new name for the destination'
        widget.use_underline = true
      end
    end

    def expander_box
      @expander_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.margin_top = 6
        box.add_css_class('linked')
      end
    end

    def entry
      @entry ||= Gtk::Entry.new.tap do |widget|
        widget.activates_default = true
        widget.hexpand = true
      end
    end

    def reset_button
      @reset_button ||= Gtk::Button.new.tap do |button|
        button.label = 'R_eset'
        button.use_underline = true
      end
    end

    def checkbox
      @checkbox ||= Gtk::CheckButton.new.tap do |widget|
        widget.label = 'Apply this action to all files and folders'
        widget.use_underline = true
      end
    end

    # The .blp's ShortcutController trigger: "Escape" closes the window.
    # Gtk::ShortcutTrigger has no string-parsing constructor bound in Ruby,
    # so this uses a plain key controller for the same effect.
    def escape_key_controller
      @escape_key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
        controller.signal_connect('key-pressed') do |_controller, keyval, _keycode, _state|
          if keyval == Gdk::KEY_Escape
            dialog.close
            true
          else
            false
          end
        end
      end
    end

    private

      def respond(response)
        @response = response
        dialog.close
      end

      def refresh_rename_sensitivity
        text = entry.text
        rename_button.sensitive = !text.empty? && text != @conflict_name
      end

      def extension_char_offset(name)
        dot = name.rindex('.')
        if dot.nil? || dot.zero?
          name.length
        else
          dot
        end
      end

      def reset_name
        entry.text = @conflict_name
        entry.grab_focus
        entry.select_region(0, extension_char_offset(@conflict_name))
      end

      def on_expanded_notify
        if expander.expanded?
          replace_button.visible = false
          rename_button.visible = true
          checkbox.sensitive = false
          entry.grab_focus

          if entry.text == @suggested_name
            start_pos = extension_char_offset(@conflict_name)
            end_pos = extension_char_offset(@suggested_name)
            entry.select_region(start_pos, end_pos)
          end
        else
          rename_button.visible = false
          replace_button.visible = true
          checkbox.sensitive = true
        end
      end
  end
end
