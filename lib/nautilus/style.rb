# frozen_string_literal: true

require 'adwaita'

module Nautilus
  # Style installs the app stylesheet.
  #
  # Ported from src/resources/style.css, which upstream loads from its
  # GResource bundle in nautilus_application_startup(). The rules themselves
  # live beside this file in data/style.css so they stay CSS; this class is
  # the Gtk::CssProvider that puts them on the display, plus the names of the
  # classes the widgets add, so a widget can be checked against the sheet.
  class Style
    PATH = ::File.expand_path('../../data/style.css', __dir__)

    # The classes style.css defines that the app's own widgets apply.
    CLASSES = %w[
      batch-rename-preview
      conflict-row
      cutout
      disk-space-free
      disk-space-used
      floating-bar
      image-frame
      nautilus-app-chooser
      nautilus-file-chooser
      nautilus-grid-view
      nautilus-list-view
      nautilus-network-view
      nautilus-pathbar
      nautilus-path-button
      nautilus-progress-indicator
      nautilus-properties
      nautilus-query-editor
      operations-list
    ].freeze

    def self.install(display = Gdk::Display.default) = new.install(display)

    def install(display)
      provider.tap do |css|
        unless display.nil?
          Gtk::StyleContext.add_provider_for_display(
            display,
            css,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end
      end
    end

    def provider
      @provider ||= Gtk::CssProvider.new.tap do |css|
        css.load_from_path(PATH)
      end
    end
  end
end
