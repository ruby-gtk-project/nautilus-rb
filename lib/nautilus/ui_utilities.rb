# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # UiUtilities holds the menu-model and UI string helpers.
  #
  # Ported from src/nautilus-ui-utilities.c. Upstream's menus come out of
  # GtkBuilder resources and are then edited in place with
  # nautilus_menu_item_change_attribute() and filter_menu_model(); the Ruby
  # bindings have no g_menu_item_new_from_model(), and this port builds its
  # menus in code rather than from .ui files, so the same operations are done
  # on a plain-Ruby description of the menu which is then rendered into a
  # Gio::Menu. Rendering into the *same* Gio::Menu instance is what
  # nautilus_gmenu_set_from_model() does, and it is why a Gtk::PopoverMenu
  # holding the model notices the change.
  module UiUtilities
    # Attribute names GMenuItem understands, mapped from the keys a menu
    # description uses.
    ITEM_ATTRIBUTES = {
      verb_icon:    'verb-icon',
      hidden_when:  'hidden-when',
      accel:        'accel',
      item_name:    'nautilus-menu-item',
      show_in_mode: 'show-in-mode',
      show_in_view: 'show-in-view',
    }.freeze

    module_function

    # nautilus_capitalize_str(): upcases the first character only.
    def capitalize_str(string)
      if string.nil?
        nil
      else
        string.to_s.sub(/\A./) { |first| first.upcase }
      end
    end

    # nautilus_gmenu_set_from_model(): empties the target menu, then fills it
    # from the description. An empty or nil description leaves it empty.
    def set_from_model(target_menu, description)
      target_menu.tap do |menu|
        menu.remove_all
        Array(description).each do |entry|
          append_entry(menu, entry)
        end
      end
    end

    def build_menu(description) = set_from_model(Gio::Menu.new, description)

    # filter_menu_model() for "show-in-mode": drops every item which declares
    # the attribute without listing this mode, recursing into sections.
    def filter_for_mode(description, mode) = filter(description, :show_in_mode, mode.to_s)

    # filter_menu_model() for "show-in-view".
    def filter_for_view(description, view_name) = filter(description, :show_in_view, view_name.to_s)

    def filter(description, key, value)
      Array(description).filter_map do |entry|
        if keeps?(entry, key, value)
          filter_entry(entry, key, value)
        end
      end
    end

    # nautilus_menu_item_change_attribute(): finds the item carrying
    # `nautilus-menu-item` and replaces one of its attributes.
    def change_attribute(description, item_name, attribute, new_value)
      Array(description).map do |entry|
        if entry[:item_name] == item_name
          entry.merge(attribute => new_value)
        else
          change_in_children(
            entry,
            item_name,
            attribute,
            new_value,
          )
        end
      end
    end

    # nautilus_date_time_is_between_dates().
    def date_time_between_dates(date, initial_date, end_date)
      date >= initial_date && date <= end_date
    end

    # nautilus_show_ok_dialog(): an alert with a single "OK" response.
    def show_ok_dialog(heading, body, parent)
      Adwaita::AlertDialog.new(heading, body).tap do |dialog|
        dialog.add_response('ok', 'OK')
        dialog.default_response = 'ok'
        dialog.present(parent)
      end
    end

    # nautilus_ui_timed_wait_start(): an operation normally fast enough not to
    # need a dialog gets one only once it has been running for `duration`
    # milliseconds, and the dialog's one response cancels it.
    def timed_wait_start(wait_message, parent_window, duration: 1000, &cancel_callback)
      timed_waits[cancel_callback] = GLib::Timeout.add(duration) do
        timed_waits.delete(cancel_callback)
        timed_wait_dialog(wait_message, parent_window, &cancel_callback)
        GLib::Source::REMOVE
      end
      cancel_callback
    end

    # nautilus_ui_timed_wait_stop(): the operation finished, so the dialog is
    # either never shown or dismissed.
    def timed_wait_stop(cancel_callback)
      timed_waits.delete(cancel_callback).then do |timeout_id|
        unless timeout_id.nil?
          GLib::Source.remove(timeout_id)
        end
      end
      timed_wait_dialogs.delete(cancel_callback)&.close
    end

    def timed_waits = @timed_waits ||= {}

    def timed_wait_dialogs = @timed_wait_dialogs ||= {}

    def timed_wait_dialog(wait_message, parent_window, &cancel_callback)
      Adwaita::AlertDialog.new(wait_message, nil).tap do |dialog|
        dialog.add_response('cancel', 'Cancel')
        dialog.close_response = 'cancel'
        dialog.signal_connect('response') do |_dialog, response|
          timed_wait_dialogs.delete(cancel_callback)
          if response == 'cancel'
            cancel_callback.call
          end
        end
        timed_wait_dialogs[cancel_callback] = dialog
        dialog.present(parent_window)
      end
    end

    def append_entry(menu, entry)
      if entry.key?(:section)
        append_section(menu, entry)
      elsif entry.key?(:submenu)
        menu.append_submenu(entry[:label], build_menu(entry[:submenu]))
      else
        menu.append_item(menu_item(entry))
      end
    end

    def append_section(menu, entry)
      build_menu(entry[:section]).tap do |section|
        Gio::MenuItem.new(entry[:label], nil).tap do |item|
          item.set_section(section)
          set_attributes(item, entry)
          menu.append_item(item)
        end
      end
    end

    # An item's `target:` is written the way a blueprint writes it, as GVariant
    # text — "('name', false)", "'simple'", "3". GLib::Variant.new cannot build
    # a tuple from a Ruby array in these bindings (it produces an array
    # variant), and GLib::Variant.parse can, so the text form is what this
    # takes.
    def menu_item(entry)
      Gio::MenuItem.new(entry[:label], item_action(entry)).tap do |item|
        unless entry[:target].nil?
          item.set_action_and_target_value(entry[:action], target_variant(entry))
        end
        set_attributes(item, entry)
      end
    end

    # A "custom:" slot has no action of its own; the popover fills it with the
    # widget registered under that name.
    # `target_type:` names the GVariant type the action declares, so an int32
    # target is not built as the int64 an unannotated number parses to.
    def target_variant(entry)
      if entry[:target_type].nil?
        GLib::Variant.parse(entry[:target].to_s)
      else
        GLib::Variant.parse(entry[:target].to_s, GLib::VariantType.new(entry[:target_type]))
      end
    end

    def item_action(entry)
      if entry.key?(:custom)
        nil
      else
        entry[:action]
      end
    end

    def set_attributes(item, entry)
      if entry.key?(:custom)
        item.set_attribute_value('custom', GLib::Variant.new(entry[:custom].to_s))
      end
      if entry.key?(:display_hint)
        item.set_attribute_value('display-hint', GLib::Variant.new(entry[:display_hint].to_s))
      end
      ITEM_ATTRIBUTES.each do |key, attribute|
        unless entry[key].nil?
          item.set_attribute_value(attribute, GLib::Variant.new(entry[key].to_s))
        end
      end
      item
    end

    def keeps?(entry, key, value)
      entry[key].nil? || entry[key].to_s.split(',').include?(value)
    end

    def filter_entry(entry, key, value)
      if entry.key?(:section)
        entry.merge(section: filter(entry[:section], key, value))
      elsif entry.key?(:submenu)
        entry.merge(submenu: filter(entry[:submenu], key, value))
      else
        entry
      end
    end

    def change_in_children(entry, item_name, attribute, new_value)
      if entry.key?(:section)
        entry.merge(
          section: change_attribute(
            entry[:section],
            item_name,
            attribute,
            new_value,
          ),
        )
      elsif entry.key?(:submenu)
        entry.merge(
          submenu: change_attribute(
            entry[:submenu],
            item_name,
            attribute,
            new_value,
          ),
        )
      else
        entry
      end
    end
  end
end
