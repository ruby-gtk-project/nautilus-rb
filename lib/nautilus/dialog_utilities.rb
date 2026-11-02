# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # DialogUtilities builds the generic confirm and error alerts the file
  # operations put in front of the user.
  #
  # Ported from src/nautilus-dialog-utilities.c. The response ids and labels,
  # the order the responses are added in (which is the order the dialog shows
  # them), which of them is destructive, which is the default, and the
  # two-second delay before a dialog becomes interactive are all upstream's.
  module DialogUtilities
    # Seconds before a delayed dialog accepts input, so an accidental Return
    # on a dialog that appeared under the pointer cannot confirm it.
    BUTTON_ACTIVATION_DELAY_IN_SECONDS = 2

    CANCEL = 'cancel'
    COPY_FORCE = 'copy_force'
    DELETE = 'delete'
    DELETE_ALL = 'delete_all'
    EMPTY_TRASH = 'empty_trash'
    MERGE = 'merge'
    PROCEED = 'proceed'
    REPLACE = 'replace'
    RETRY = 'retry'
    SKIP = 'skip'
    SKIP_ALL = 'skip_all'
    SKIP_FILES = 'skip_files'

    # add_dialog_responses(), in its exact order: id, label, whether it is
    # destructive, and whether adding it makes it the default response.
    RESPONSES = [
      [COPY_FORCE, 'Copy _Anyway', false, false],
      [PROCEED, 'Proceed _Anyway', false, false],
      [EMPTY_TRASH, 'Empty _Trash', true, true],
      [MERGE, '_Merge', false, false],
      [REPLACE, '_Replace', false, false],
      [SKIP_ALL, 'S_kip All', false, true],
      [SKIP, '_Skip', false, true],
      [SKIP_FILES, '_Skip Files', false, true],
      [DELETE_ALL, 'Delete _All', true, false],
      [DELETE, '_Delete', true, true],
      [RETRY, '_Retry', false, true],
    ].freeze

    module_function

    # nautilus_dialog_response_from_string(): an unknown response counts as a
    # cancel.
    def response_from_string(response)
      RESPONSES.map(&:first).push(CANCEL).then do |known|
        if known.include?(response)
          response
        else
          CANCEL
        end
      end
    end

    # nautilus_dialog_with_responses(): the alert, its optional selectable
    # details label, and the responses named in `responses`.
    def dialog_with_responses(heading, body, details: nil, delay_interactivity: false, responses: [])
      Adwaita::AlertDialog.new(heading, body).tap do |dialog|
        if delay_interactivity
          delay(dialog)
        end
        unless details.nil?
          dialog.extra_child = details_label(details)
        end
        add_responses(dialog, responses)
      end
    end

    def add_responses(dialog, responses)
      dialog.tap do |alert|
        # Cancel is always available, and is both the default and the close
        # response until a later response takes the default over.
        alert.add_response(CANCEL, '_Cancel')
        alert.default_response = CANCEL
        alert.close_response = CANCEL

        RESPONSES.each do |(id, label, destructive, defaults)|
          if responses.include?(id)
            add_response(
              alert,
              id,
              label,
              destructive,
              defaults,
            )
          end
        end
      end
    end

    def add_response(dialog, id, label, destructive, defaults)
      dialog.add_response(id, label)
      if destructive
        dialog.set_response_appearance(id, :destructive)
      end
      if defaults
        dialog.default_response = id
      end
    end

    def details_label(details)
      Gtk::Label.new(details).tap do |label|
        label.wrap = true
        label.selectable = true
        label.xalign = 0
        label.can_focus = false
      end
    end

    def delay(dialog)
      dialog.sensitive = false
      GLib::Timeout.add_seconds(BUTTON_ACTIVATION_DELAY_IN_SECONDS) do
        unless dialog.destroyed?
          dialog.sensitive = true
        end
        GLib::Source::REMOVE
      end
    end
  end
end
