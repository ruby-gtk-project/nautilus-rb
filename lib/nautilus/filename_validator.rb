# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # FilenameValidator decides whether a typed filename may be used, and what
  # feedback the dialog showing it should display.
  #
  # Ported from src/nautilus-filename-validator.c. It drives the
  # `has-feedback` / `feedback-text` / `passed` / `will-overwrite` states of
  # the new-folder dialog, the compress dialog, the rename popover and the
  # batch-rename dialog. Upstream exposes these as GObject properties bound
  # from the blueprint; here the dialogs register callbacks with
  # #on_state_changed and #on_name_accepted, which is what those bindings and
  # the "name-accepted" signal amount to.
  class FilenameValidator
    DUPLICATED_LABEL_TIMEOUT = 500

    # pathconf(_PC_NAME_MAX) and _PC_PATH_MAX are not reachable from Ruby, so
    # the POSIX minima Linux guarantees stand in for them, the way
    # nautilus_get_max_child_name_length_for_location() combines the two.
    NAME_MAX = 255
    PATH_MAX = 4096

    def initialize(containing_directory: nil, target_is_folder: false, allow_overwrite: false)
      @containing_directory = containing_directory
      @target_is_folder = target_is_folder
      @allow_overwrite = allow_overwrite
      @original_name = nil
      @new_name = ''
      @feedback_text = nil
      @passed = false
      @valid_name = false
      @duplicated_name = false
      @duplicated_is_folder = false
      @will_overwrite = false
      @duplicated_label_timeout_id = nil
      @state_handlers = []
      @accepted_handlers = []
    end

    attr_reader :feedback_text, :new_name, :containing_directory
    attr_accessor :original_name

    def target_is_folder=(is_folder)
      @target_is_folder = is_folder
    end

    def allow_overwrite=(allow)
      @allow_overwrite = allow
    end

    def containing_directory=(directory)
      @containing_directory = directory
      @children = nil
    end

    def has_feedback? = !@feedback_text.nil?
    def passed? = @passed
    def will_overwrite? = @will_overwrite
    def target_is_folder? = @target_is_folder

    def on_state_changed(&handler)
      @state_handlers << handler
      handler
    end

    def on_name_accepted(&handler)
      @accepted_handlers << handler
      handler
    end

    # The name the dialog should act on: the typed text with its leading and
    # trailing whitespace removed, as nautilus_filename_strip() does.
    def stripped_name = @new_name.to_s.strip

    def new_name=(text)
      @new_name = text.to_s
    end

    # nautilus_filename_validator_validate(): recheck and update the feedback.
    def validate
      unless @containing_directory.nil?
        process_new_name
        # A duplicate is only reported once the user has stopped typing long
        # enough, and only when no other message has the floor.
        if @duplicated_name && @valid_name
          schedule_duplicated_label
        end
      end
    end

    # nautilus_filename_validator_try_accept(): recheck, then either accept
    # the name or report the duplicate immediately, since the user asked.
    def try_accept
      unless @containing_directory.nil?
        process_new_name
        if @passed
          @accepted_handlers.each { |handler| handler.call(self) }
        elsif @duplicated_name && @valid_name
          show_duplicated_label
        end
      end
    end

    private

      def process_new_name
        stripped_name.then do |name|
          @valid_name = name_valid?(name)
          set_feedback_text(@error_message)
          existing_child(name).then do |existing|
            @duplicated_name = !existing.nil? && !ignore_existing?(existing)
            unless existing.nil?
              @duplicated_is_folder = folder?(existing)
            end
          end
          update_passed
        end
      end

      def update_passed
        (@valid_name && (@allow_overwrite || !@duplicated_name)).then do |passed|
          @passed = passed
          @will_overwrite = @allow_overwrite && passed && @duplicated_name
        end
        clear_duplicated_timeout
        notify_state
      end

      # nautilus_filename_validator_name_is_valid(): empty, "/", "." and ".."
      # are rejected; a leading "." passes but warns about the side effect.
      def name_valid?(name)
        @error_message = nil
        if name.empty?
          false
        elsif name.include?('/')
          reject('Folder names cannot contain “/”', 'File names cannot contain “/”')
        elsif ['.', '..'].include?(name)
          reject('A folder cannot be called “.” or “..”', 'A file cannot be called “.” or “..”')
        elsif too_long?(name)
          reject('Folder name is too long', 'File name is too long')
        else
          warn_about_hidden(name)
          true
        end
      end

      def reject(folder_message, file_message)
        @error_message = for_target(folder_message, file_message)
        false
      end

      def warn_about_hidden(name)
        if name.start_with?('.')
          @error_message = for_target(
            'Folders with “.” at the beginning of their name are hidden',
            'Files with “.” at the beginning of their name are hidden',
          )
        end
      end

      def for_target(folder_message, file_message)
        if @target_is_folder
          folder_message
        else
          file_message
        end
      end

      def too_long?(name)
        max_child_name_length.then do |maximum|
          if maximum == -1
            false
          else
            name.bytesize > maximum
          end
        end
      end

      # nautilus_get_max_child_name_length_for_location(): only local paths
      # have a limit this port can work out.
      def max_child_name_length
        directory_path.then do |path|
          if path.nil?
            -1
          else
            [[(PATH_MAX - 1) - path.bytesize, 0].max, NAME_MAX].min
          end
        end
      end

      def directory_path
        if @containing_directory.respond_to?(:path)
          @containing_directory.path
        else
          @containing_directory.to_s
        end
      end

      # nautilus_directory_get_file_by_name().
      def existing_child(name)
        if name.empty?
          nil
        else
          children.find { |child| child == name }
        end
      end

      def children
        @children ||= read_children
      end

      # GLocalFileEnumerator is not enumerable in the Ruby bindings, so the
      # only way through it is next_file() until it returns nil.
      def read_children
        Gio::File.new_for_path(directory_path.to_s)
                 .enumerate_children('standard::name', :none, nil).then do |enumerator|
          names = []
          while (info = enumerator.next_file(nil))
            names << info.name
          end
          enumerator.close
          names
        end
      rescue GLib::Error
        []
      end

      def folder?(name)
        ::File.directory?(::File.join(directory_path.to_s, name))
      end

      def ignore_existing?(existing)
        !@original_name.nil? && existing == @original_name
      end

      def set_feedback_text(text)
        unless @feedback_text == text
          @feedback_text = text
          notify_state
        end
      end

      def schedule_duplicated_label
        clear_duplicated_timeout
        @duplicated_label_timeout_id = GLib::Timeout.add(DUPLICATED_LABEL_TIMEOUT) do
          @duplicated_label_timeout_id = nil
          show_duplicated_label
          GLib::Source::REMOVE
        end
      end

      def clear_duplicated_timeout
        unless @duplicated_label_timeout_id.nil?
          GLib::Source.remove(@duplicated_label_timeout_id)
          @duplicated_label_timeout_id = nil
        end
      end

      def show_duplicated_label
        set_feedback_text(
          for_duplicate(
            'A folder with that name already exists',
            'A file with that name already exists',
          ),
        )
      end

      def for_duplicate(folder_message, file_message)
        if @duplicated_is_folder
          folder_message
        else
          file_message
        end
      end

      def notify_state
        @state_handlers.each { |handler| handler.call(self) }
      end
  end
end
