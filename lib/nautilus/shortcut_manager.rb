# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

module Nautilus
  # ShortcutManager is a bin container that limits the scope of
  # Gtk::ShortcutScope::MANAGED shortcuts.
  #
  # Ported from src/nautilus-shortcut-manager.c: the primary use case is to
  # prevent keyboard shortcuts from being triggered while an Adwaita::Dialog
  # is presented. This assumes an implementation detail: that Adwaita dialogs
  # are internally children of Adwaita::Window/Adwaita::ApplicationWindow,
  # but not children of that window's own `child`.
  #
  # Upstream is simply an AdwBin augmented with the GtkShortcutManager
  # interface, whose default implementation is enough for the purpose; this
  # is the same shape, an Adwaita::Bin that includes Gtk::ShortcutManager.
  class ShortcutManager < Adwaita::Bin
    include Gtk::ShortcutManager

    type_register
  end
end
