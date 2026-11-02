# frozen_string_literal: true

require 'adwaita'
require_relative 'directory'
require_relative 'global_preferences'

module Nautilus
  # ListBase is what the grid view, the list view and the network view share:
  # the selection model, the zoom levels, the cell bookkeeping, activation,
  # the context-menu gestures and the drag and drop handling.
  #
  # Ported from src/nautilus-list-base.c and nautilus-list-base-private.h,
  # which is an abstract GtkWidget subclass the three views derive from.
  # Subclasses here supply #view (the Gtk::ListBase widget), #view_info (the
  # zoom range) and #icon_size, exactly the three virtual methods upstream's
  # NautilusListBaseClass declares.
  class ListBase
    # GTK_INVALID_LIST_POSITION, which arrives as a large unsigned integer
    # rather than nil.
    INVALID_POSITION = 0xFFFFFFFF

    def initialize(directory:, on_activate: nil, on_context_menu: nil, on_selection_changed: nil)
      @directory = directory
      @on_activate = on_activate
      @on_context_menu = on_context_menu
      @on_selection_changed = on_selection_changed
      @cells = {}
      @next_cell_id = 0
      @zoom_level = view_info.fetch(:zoom_level_standard)
    end

    attr_reader :directory, :zoom_level

    def directory=(directory)
      @directory = directory
      selection_model.model = directory.list_store
      directory
    end

    # --- The three hooks a subclass fills in ---------------------------------

    # The zoom range, as NautilusViewInfo carries it.
    def view_info
      { view_id: 'list', zoom_level_min: 0, zoom_level_max: 0, zoom_level_standard: 0 }
    end

    def view = raise(NotImplementedError)

    def icon_size = 32

    # --- Selection ----------------------------------------------------------

    def selection_model
      @selection_model ||= Gtk::MultiSelection.new(@directory.list_store).tap do |model|
        model.signal_connect('selection-changed') do
          @on_selection_changed&.call(selected_files)
        end
      end
    end

    # Gtk::Bitset cannot be iterated from Ruby — it exposes only #contains,
    # #size and #minimum — so the selected positions are found by asking the
    # model about each row.
    def selected_positions
      (0...selection_model.n_items).select { |position| selection_model.selected?(position) }
    end

    # The files, read from the directory rather than from the model: a
    # Nautilus::File handed back by GTK can be a fresh wrapper with none of
    # its attributes on it.
    def selected_files
      selected_positions.filter_map { |position| @directory.file_at(position) }
    end

    def select_all = selection_model.select_all

    def unselect_all = selection_model.unselect_all

    # view.invert-selection.
    def invert_selection
      selected_positions.then do |selected|
        (0...selection_model.n_items).each do |position|
          if selected.include?(position)
            selection_model.unselect_item(position)
          else
            selection_model.select_item(position, false)
          end
        end
      end
    end

    # view.select-pattern: a shell glob over the display names.
    def select_pattern(pattern)
      unselect_all
      (0...selection_model.n_items).each do |position|
        @directory.file_at(position).then do |file|
          if !file.nil? && ::File.fnmatch?(pattern, file.display_name, ::File::FNM_CASEFOLD)
            selection_model.select_item(position, false)
          end
        end
      end
    end

    def select_file(file)
      @directory.visible_files.index { |candidate| candidate.uri == file.uri }.then do |position|
        unless position.nil?
          selection_model.select_item(position, true)
          scroll_to(position)
        end
      end
    end

    def scroll_to(position)
      view.scroll_to(
        position,
        nil,
        :select,
        nil,
      )
    rescue StandardError
      nil
    end

    # --- Zoom ---------------------------------------------------------------

    def zoom_level=(level)
      @zoom_level = level.clamp(view_info.fetch(:zoom_level_min), view_info.fetch(:zoom_level_max))
      apply_zoom_level
      @zoom_level
    end

    def zoom_in
      self.zoom_level = @zoom_level + 1
    end

    def zoom_out
      self.zoom_level = @zoom_level - 1
    end

    def zoom_standard
      self.zoom_level = view_info.fetch(:zoom_level_standard)
    end

    def can_zoom_in? = @zoom_level < view_info.fetch(:zoom_level_max)
    def can_zoom_out? = @zoom_level > view_info.fetch(:zoom_level_min)

    # Reaches every cell on screen, which is how a zoom or a caption change
    # shows up on rows that are already bound.
    def apply_zoom_level
      @cells.each_value { |cell| cell.icon_size = icon_size }
    end

    def reload
      @directory.reload
    end

    # --- Cell bookkeeping ---------------------------------------------------

    # The cell objects are kept in a Hash keyed by an id stored in the cell
    # widget's name, because a Gtk::ListItem handed to the bind handler is not
    # guaranteed to be the same Ruby object the setup handler saw.
    def register_cell(cell)
      (@next_cell_id += 1).tap do |id|
        @cells[id] = cell
        cell.root.name = "nautilus-cell-#{id}"
      end
    end

    def cell_for(widget)
      @cells[cell_id_of(widget)]
    end

    def forget_cell(widget)
      @cells.delete(cell_id_of(widget))
    end

    def cell_id_of(widget)
      widget.name.to_s.split('-').last.to_i
    end

    # --- Drag and drop ------------------------------------------------------

    # The drop target the view's background carries, which
    # nautilus_list_base_setup_drop_target() sets up for the same actions.
    # The dropped value is a Gdk::FileList, whose #files are the dropped
    # locations.
    def drop_target(&on_drop)
      Gtk::DropTarget.new(Gdk::FileList, [:copy, :move, :link]).tap do |target|
        target.signal_connect('drop') do |_target, value, x, y|
          on_drop.call(value.files, x, y)
        end
      end
    end

    private

      def activate(position)
        unless position == INVALID_POSITION
          @on_activate&.call(@directory.file_at(position))
        end
      end

      def show_context_menu(position, x, y)
        @on_context_menu&.call(@directory.file_at(position), x, y)
      end
  end
end
