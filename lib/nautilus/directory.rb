# frozen_string_literal: true

require 'adwaita'
require_relative 'file'

module Nautilus
  # Directory is the list of files at one location, kept up to date.
  #
  # Stands in for the model layer of src/nautilus-directory.c and
  # nautilus-directory-async.c: the children of a location, a monitor that
  # notices changes to them, and the sort the view asks for. Upstream's
  # asynchronous attribute machinery has no counterpart — one
  # enumerate_children() call fetches every attribute the columns need.
  #
  # The Ruby array is the source of truth and the Gio::ListStore mirrors it.
  # Reading a Nautilus::File back out of a GTK model can hand back a wrapper
  # for memory GTK has already dropped, so nothing here reads from the store.
  class Directory
    # The locations with a name and an icon of their own, as
    # nautilus_file_get_display_name() special-cases them.
    SPECIAL_LOCATIONS = {
      'recent:///'  => { name: 'Recent', icon: 'document-open-recent-symbolic' },
      'starred:///' => { name: 'Starred', icon: 'starred-symbolic' },
      'trash:///'   => { name: 'Trash', icon: 'user-trash-symbolic' },
      'network:///' => { name: 'Network', icon: 'network-workgroup-symbolic' },
    }.freeze

    def self.for_uri(uri) = new(Gio::File.new_for_uri(uri))
    def self.for_path(path) = new(Gio::File.new_for_path(path))
    def self.home = for_path(Dir.home)

    def initialize(location)
      @location = location
      @files = []
      @sort_attribute = 'name'
      @reversed = false
      @directories_first = true
      @show_hidden = false
      @load_handlers = []
      @error_handlers = []
    end

    attr_reader :location, :files, :sort_attribute
    attr_reader :reversed
    alias reversed? reversed

    def uri = @location.uri
    def path = @location.path

    # The name the pathbar's last button and the window title show.
    def display_name
      SPECIAL_LOCATIONS.fetch(uri, nil).then do |special|
        if special
          special[:name]
        else
          local_display_name
        end
      end
    end

    def icon_name
      SPECIAL_LOCATIONS.fetch(uri, nil).then do |special|
        if special
          special[:icon]
        else
          'folder-symbolic'
        end
      end
    end

    def home? = path == Dir.home
    def trash? = uri.start_with?('trash:')
    alias in_trash? trash?
    def recent? = uri.start_with?('recent:')
    def starred? = uri.start_with?('starred:')
    def network? = uri.start_with?('network:')

    # Which default set of visible columns this location gets.
    def kind
      if recent?
        :recent
      elsif trash?
        :trash
      else
        :folder
      end
    end

    def on_loaded(&handler)
      @load_handlers << handler
      handler
    end

    def on_error(&handler)
      @error_handlers << handler
      handler
    end

    # The model the views bind to. It holds the visible files in the order
    # they are shown, so a Gtk::ListItem's position indexes #visible_files.
    #
    # The hidden-files setting and the sort are both applied to the Ruby array
    # rather than through a Gtk::FilterListModel and a Gtk::SortListModel,
    # because a Nautilus::File read back out of a GTK model can arrive as a
    # fresh wrapper with none of this object's state on it.
    def list_store = @list_store ||= Gio::ListStore.new(Nautilus::File)

    def visible_files
      @files.reject do |file|
        !@show_hidden && file.hidden?
      end
    end

    def file_at(position) = visible_files[position]

    def show_hidden? = @show_hidden

    def show_hidden=(show_hidden)
      @show_hidden = show_hidden
      refill_store
      show_hidden
    end

    def sort(attribute: @sort_attribute, reversed: @reversed, directories_first: @directories_first)
      @sort_attribute = attribute.to_s
      @reversed = reversed
      @directories_first = directories_first
      resort
    end

    def directories_first? = @directories_first

    # nautilus_directory_get_file_by_name().
    def file_by_name(name) = @files.find { |file| file.name == name }

    def load
      @files = read_files
      refill_store
      resort
      @load_handlers.each { |handler| handler.call(self) }
      self
    rescue GLib::Error => error
      @error_handlers.each { |handler| handler.call(self, error) }
      self
    end

    alias reload load

    # The monitor that makes an external change show up in the view, matching
    # nautilus_directory_monitor_add().
    def monitor
      @monitor ||= @location.monitor_directory(:watch_moves, nil).tap do |watch|
        watch.signal_connect('changed') do |_monitor, _file, _other, _event|
          schedule_reload
        end
      end
    rescue GLib::Error
      nil
    end

    def cancel_monitor
      unless @monitor.nil?
        @monitor.cancel
        @monitor = nil
      end
    end

    private

      def local_display_name
        if home?
          'Home'
        elsif @location.path == '/'
          'Operating System'
        else
          @location.basename.to_s
        end
      end

      # GLocalFileEnumerator is not enumerable in the Ruby bindings; the only
      # way through it is next_file() until it returns nil.
      def read_files
        @location.enumerate_children(Nautilus::File::ATTRIBUTES, :none, nil).then do |enumerator|
          files = []
          while (info = enumerator.next_file(nil))
            files << Nautilus::File.new(enumerator.get_child(info), info)
          end
          enumerator.close
          files
        end
      end

      def refill_store
        list_store.tap do |store|
          store.remove_all
          visible_files.each { |file| store.append(file) }
        end
      end

      # Sorting the array and refilling the store keeps the store's order and
      # the array's order the same, which is what the views' position-to-file
      # lookups rely on.
      def resort
        @files.sort! { |one, other| compare(one, other) }
        refill_store
        self
      end

      def compare(one, other)
        directory_rank(one, other).then do |by_kind|
          if by_kind.zero?
            compare_attribute(one, other)
          else
            by_kind
          end
        end
      end

      def directory_rank(one, other)
        if !@directories_first || one.directory? == other.directory?
          0
        elsif one.directory?
          -1
        else
          1
        end
      end

      def compare_attribute(one, other)
        (one.sort_key(@sort_attribute) <=> other.sort_key(@sort_attribute)).then do |result|
          if result.zero?
            one.collation_key <=> other.collation_key
          elsif @reversed
            -result
          else
            result
          end
        end
      end

      # A burst of file-monitor events is one reload, once the burst is over.
      def schedule_reload
        unless @reload_timeout_id.nil?
          GLib::Source.remove(@reload_timeout_id)
        end
        @reload_timeout_id = GLib::Timeout.add(300) do
          @reload_timeout_id = nil
          load
          GLib::Source::REMOVE
        end
      end
  end
end
