# frozen_string_literal: true

require 'adwaita'
require_relative 'directory'
require_relative 'files_view'
require_relative 'location_banner'
require_relative 'global_preferences'

module Nautilus
  # WindowSlot is one tab's content: the location it shows, the history it
  # has walked, the view showing it and the banner above it.
  #
  # Ported from src/nautilus-window-slot.c, which has no blueprint and is
  # built entirely in code. The `slot.*` action group is installed on the
  # slot's own widget, so each tab answers for itself, and the title and
  # view-icon properties the window and the toolbar bind to are read off it
  # the same way.
  class WindowSlot
    def initialize(
      location: nil,
      on_title_changed: nil,
      on_open_in_new_tab: nil,
      on_open_in_new_window: nil,
      on_bookmark: nil,
      on_unbookmark: nil
    )
      @location = location || Gio::File.new_for_path(Dir.home)
      @on_title_changed = on_title_changed
      @on_open_in_new_tab = on_open_in_new_tab
      @on_open_in_new_window = on_open_in_new_window
      @on_bookmark = on_bookmark
      @on_unbookmark = on_unbookmark
      @back_history = []
      @forward_history = []
    end

    attr_reader :location, :back_history, :forward_history

    def build
      root.tap do |box|
        box.append(location_banner.build)
        box.append(files_view.build)

        install_actions
        load_location
      end
    end

    def root
      @root ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.hexpand = true
        box.vexpand = true
      end
    end

    def directory = @directory ||= Directory.new(@location)

    def files_view
      @files_view ||= FilesView.new(
        directory:             directory,
        on_open_location:      ->(target) { open_location(target) },
        on_open_in_new_tab:    ->(target) { @on_open_in_new_tab&.call(target) },
        on_open_in_new_window: ->(target) { @on_open_in_new_window&.call(target) },
      )
    end

    def location_banner
      @location_banner ||= LocationBanner.new(on_empty_trash: -> { files_view.empty_trash })
    end

    def actions = @actions ||= Gio::SimpleActionGroup.new

    # The tab's title, which the window's own title follows.
    def title = directory.display_name

    # The icon and tooltip the view-controls split button shows: the icon of
    # the view it would switch to.
    def view_icon_name
      if files_view.mode == :list
        'view-grid-symbolic'
      else
        'view-list-symbolic'
      end
    end

    def view_tooltip
      if files_view.mode == :list
        'Grid View'
      else
        'List View'
      end
    end

    # nautilus_window_slot_open_location_full().
    def open_location(target)
      unless target.nil? || target.uri == @location.uri
        @back_history.unshift(directory)
        @forward_history.clear
        go_to(target)
      end
    end

    # slot.back / slot.back-n.
    def back(steps = 1)
      walk(@back_history, @forward_history, steps)
    end

    # slot.forward / slot.forward-n.
    def forward(steps = 1)
      walk(@forward_history, @back_history, steps)
    end

    # slot.up: the parent folder.
    def up
      @location.parent.then do |parent_location|
        unless parent_location.nil?
          open_location(parent_location)
        end
      end
    end

    # slot.down: the selected folder, which is what Alt+Down opens.
    def down
      files_view.selected_files.find(&:directory?).then do |folder|
        unless folder.nil?
          open_location(folder.location)
        end
      end
    end

    def reload
      directory.reload
      files_view.reload
    end

    def can_go_back? = !@back_history.empty?
    def can_go_forward? = !@forward_history.empty?

    private

      def go_to(target)
        @location = target
        @directory = Directory.new(target)
        files_view.directory = @directory
        location_banner.location = target
        @on_title_changed&.call(self)
        refresh_action_availability
      end

      def load_location
        location_banner.location = @location
        @on_title_changed&.call(self)
        refresh_action_availability
      end

      # Walking the history moves the current location onto the other list,
      # and everything it stepped over with it.
      def walk(from, to, steps)
        steps.abs.clamp(0, from.size).then do |count|
          unless count.zero?
            from.shift(count).then do |stepped|
              to.unshift(*stepped[0..-2].reverse, directory)
              go_to(stepped.last.location)
            end
          end
        end
      end

      # --- The slot action group --------------------------------------------

      def install_actions
        simple_actions.each do |name, handler|
          add_action(
            name,
            Gio::SimpleAction.new(name).tap do |action|
                        action.signal_connect('activate') { handler.call }
                      end,
          )
        end
        add_action('back-n', history_action('back-n') { |steps| back(steps) })
        add_action('forward-n', history_action('forward-n') { |steps| forward(steps) })
        add_action('open-location', open_location_action)
        add_action('files-view-mode', files_view_mode_action)
        root.insert_action_group('slot', actions)
        refresh_action_availability
      end

      def add_action(name, action)
        action_objects[name] = action
        actions.add_action(action)
      end

      def action_objects = @action_objects ||= {}

      def simple_actions
        {
          'back'                         => -> { back },
          'forward'                      => -> { forward },
          'up'                           => -> { up },
          'down'                         => -> { down },
          'reload'                       => -> { reload },
          'stop'                         => -> { files_view.stop_loading },
          'files-view-mode-toggle'       => -> { toggle_view_mode },
          'bookmark-current-directory'   => -> { @on_bookmark&.call(@location) },
          'unbookmark-current-directory' => -> { @on_unbookmark&.call(@location) },
          'star-current-directory'       => -> { set_starred(true) },
          'unstar-current-directory'     => -> { set_starred(false) },
        }
      end

      # slot.back-n and slot.forward-n take the number of steps as an int32,
      # which is the target the history menus carry.
      def history_action(name, &handler)
        Gio::SimpleAction.new(name, GLib::VariantType.new('i')).tap do |action|
          action.signal_connect('activate') do |_action, parameter|
            handler.call(parameter.to_i)
          end
        end
      end

      def open_location_action
        Gio::SimpleAction.new('open-location', GLib::VariantType.new('s')).tap do |action|
          action.signal_connect('activate') do |_action, parameter|
            open_location(Gio::File.new_for_uri(parameter.to_s))
          end
        end
      end

      # slot.files-view-mode takes the view's id, as the Ctrl+1 / Ctrl+2
      # shortcuts do.
      def files_view_mode_action
        Gio::SimpleAction.new('files-view-mode', GLib::VariantType.new('s')).tap do |action|
          action.signal_connect('activate') do |_action, parameter|
            files_view.mode = mode_for(parameter.to_s)
            @on_title_changed&.call(self)
          end
        end
      end

      def mode_for(view_id)
        if view_id == 'list'
          :list
        else
          :grid
        end
      end

      def toggle_view_mode
        files_view.toggle_mode
        @on_title_changed&.call(self)
      end

      def set_starred(starred)
        Nautilus::File.for_location(@location).starred = starred
        refresh_action_availability
      rescue GLib::Error
        nil
      end

      def refresh_action_availability
        {
          'back'                     => can_go_back?,
          'forward'                  => can_go_forward?,
          'up'                       => !@location.parent.nil?,
          'down'                     => true,
          'star-current-directory'   => !starred?,
          'unstar-current-directory' => starred?,
        }.each do |name, enabled|
          action_objects[name]&.set_enabled(enabled == true)
        end
      end

      def starred? = Nautilus::File.starred_uris.include?(@location.uri)
  end
end
