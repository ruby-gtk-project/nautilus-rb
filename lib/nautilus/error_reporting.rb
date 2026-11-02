# frozen_string_literal: true

require 'adwaita'
require_relative 'ui_utilities'

module Nautilus
  # ErrorReporting turns a failed rename, group, owner or permissions change
  # into the alert the user sees.
  #
  # Ported from src/nautilus-error-reporting.c. Every branch below is one of
  # upstream's: the heading is fixed per operation, and the body is chosen
  # from the GIO error code, falling back to the "Sorry, could not …: %s"
  # form carrying the raw error message when the code is one upstream has no
  # wording for.
  module ErrorReporting
    # FAT_FORBIDDEN_CHARACTERS: the characters a rename onto a FAT filesystem
    # is rejected for, named one at a time in the error.
    FAT_FORBIDDEN_CHARACTERS = '/:;*?"<>'

    module_function

    def report_error_loading_directory(display_name, error, parent)
      loading_message(display_name, error).then do |message|
        UiUtilities.show_ok_dialog('This location could not be displayed.', message, parent)
      end
    end

    def report_error_renaming_file(display_name, new_name, error, parent)
      renaming_message(display_name, new_name, error).then do |message|
        UiUtilities.show_ok_dialog('The item could not be renamed.', message, parent)
      end
    end

    def report_error_setting_group(display_name, error, parent)
      group_message(display_name, error).then do |message|
        UiUtilities.show_ok_dialog('The group could not be changed.', message, parent)
      end
    end

    def report_error_setting_owner(display_name, error, parent)
      "Sorry, could not change the owner of “#{display_name}”: #{error.message}".then do |message|
        UiUtilities.show_ok_dialog('The owner could not be changed.', message, parent)
      end
    end

    def report_error_setting_permissions(display_name, error, parent)
      "Sorry, could not change the permissions of “#{display_name}”: #{error.message}".then do |message|
        UiUtilities.show_ok_dialog('The permissions could not be changed.', message, parent)
      end
    end

    def loading_message(display_name, error)
      case code_of(error)
      when :permission_denied
        "You do not have the permissions necessary to view the contents of “#{display_name}”."
      when :not_found
        "“#{display_name}” could not be found. Perhaps it has recently been deleted."
      else
        "Sorry, could not display all the contents of “#{display_name}”: #{error.message}"
      end
    end

    def group_message(display_name, error)
      case code_of(error)
      when :permission_denied
        "You do not have the permissions necessary to change the group of “#{display_name}”."
      else
        "Sorry, could not change the group of “#{display_name}”: #{error.message}"
      end
    end

    def renaming_message(display_name, new_name, error)
      case code_of(error)
      when :exists
        "The name “#{new_name}” is already used in this location. Please use a different name."
      when :not_found
        "There is no “#{display_name}” in this location. Perhaps it was just moved or deleted?"
      when :permission_denied
        "You do not have the permissions necessary to rename “#{display_name}”."
      when :invalid_argument, :invalid_filename
        invalid_filename_message(new_name)
      when :filename_too_long
        "The name “#{new_name}” is too long. Please use a different name."
      when :busy
        "Could not rename “#{display_name}” because a process is using it." \
          " If it's open in another application, close it before renaming it."
      else
        "Sorry, could not rename “#{display_name}” to “#{new_name}”: #{error.message}"
      end
    end

    def invalid_filename_message(new_name)
      forbidden_character(new_name).then do |character|
        if character.nil?
          "The name “#{new_name}” is not valid. Please use a different name."
        else
          "The name “#{new_name}” is not valid because it contains the character “#{character}”." \
            ' Please use a different name.'
        end
      end
    end

    def forbidden_character(new_name)
      new_name.to_s.each_char.find { |character| FAT_FORBIDDEN_CHARACTERS.include?(character) }
    end

    # GIO raises one exception class per G_IO_ERROR_* code
    # (Gio::IOError::NotFound and friends), so the switch upstream writes over
    # error->code is a switch over the class name here. Anything that is not a
    # GIO error has no code, and falls through to the generic wording.
    def code_of(error)
      if error.is_a?(Gio::IOError)
        error.class.name.to_s.split('::').last.gsub(/([a-z\d])([A-Z])/, '\\1_\\2').downcase.to_sym
      end
    end
  end
end
