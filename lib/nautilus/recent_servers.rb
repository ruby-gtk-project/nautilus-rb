# frozen_string_literal: true

require 'glib2'
require 'gio2'
require 'fileutils'
require 'securerandom'

module Nautilus
  # RecentServers tracks the "Other Locations" bookmark file GTK shares
  # across apps (~/.config/gtk-4.0/servers), reloads it when it changes on
  # disk, and reports additions/changes/removals of the virtual Gio::FileInfo
  # rows the network address bar's popover lists.
  #
  # Ported from src/nautilus-recent-servers.c: the module-level
  # nautilus_add_recent_server()/nautilus_remove_recent_server() functions are
  # the class methods below, and the NautilusRecentServers GObject (loading
  # state, the added/changed/removed signals, the idle-scheduled reload) is
  # this class's instance side, with plain callback lists standing in for the
  # signals.
  class RecentServers
    def self.instance = @instance ||= new

    def self.add(file)
      bookmarks = load
      bookmarks.then do |b|
        uri = file.uri
        title = display_name_for(file)
        b.set_title(uri, title)
        b.set_visited(uri, Time.now.to_i)
        b.add_application(uri, 'nautilus', 'nautilus %u')
        save(b)
      end
    end

    def self.display_name_for(file)
      file.query_info('standard::display-name', :none).get_attribute_as_string('standard::display-name')
    rescue StandardError
      file.basename
    end

    def self.remove(uri)
      load&.tap do |bookmarks|
        bookmarks.remove_item(uri)
        save(bookmarks)
      end
    end

    def self.server_list_path
      File.join(GLib.user_config_dir, 'gtk-4.0', 'servers')
    end

    def self.load
      path = server_list_path
      FileUtils.mkdir_p(File.dirname(path))
      bookmarks = GLib::BookmarkFile.new
      bookmarks.load_from_file(path)
      bookmarks
    rescue IOError
      bookmarks
    end

    def self.save(bookmarks)
      bookmarks.to_file(server_list_path)
    end

    def initialize
      @server_infos = {}
      @server_fields = {}
      @loading = false
      @added_callbacks = []
      @changed_callbacks = []
      @removed_callbacks = []
    end

    attr_reader :loading

    def infos = @server_infos.values

    def on_added(&block) = @added_callbacks << block
    def on_changed(&block) = @changed_callbacks << block
    def on_removed(&block) = @removed_callbacks << block

    def force_reload
      unless @reload_scheduled
        @reload_scheduled = true
        set_loading(true)
        GLib::Idle.add do
          populate_servers
          @reload_scheduled = false
          false
        end
      end
    end

    private

      def ensure_monitor
        @server_list_monitor ||= Gio::File.new_for_path(self.class.server_list_path)
                                           .monitor_file(:none)
                                           .tap { |monitor| monitor.signal_connect('changed') { force_reload } }
      end

      def populate_servers
        bookmarks = self.class.load
        bookmarks.then do |list|
          ensure_monitor

          uris = list.uris || []
          old_infos = @server_infos.dup
          added = []
          changed = []

          uris.each do |uri|
            info = @server_infos[uri]
            is_new = info.nil?

            if is_new
              info = server_file_info(uri)
              @server_infos[uri] = info
              added << info
            else
              old_infos.delete(uri)
            end

            fields = [list.get_title(uri), list.get_added(uri), list.get_visited(uri), list.get_modified(uri)]

            if is_new || @server_fields[uri] != fields
              title, added_time, visited_time, modified_time = fields
              info.display_name = title

              unless added_time.nil?
                info.creation_date_time = added_time
              end

              unless visited_time.nil?
                info.access_date_time = visited_time
              end

              unless modified_time.nil?
                info.modification_date_time = modified_time
              end

              @server_fields[uri] = fields

              unless is_new
                changed << info
              end
            end
          end

          unless old_infos.empty?
            @removed_callbacks.each { |cb| cb.call(old_infos.values) }
          end

          unless changed.empty?
            @changed_callbacks.each { |cb| cb.call(changed) }
          end

          unless added.empty?
            @added_callbacks.each { |cb| cb.call(added) }
          end

          old_infos.each_key do |uri|
            @server_infos.delete(uri)
            @server_fields.delete(uri)
          end
        end

        set_loading(false)
      end

      def server_file_info(uri)
        Gio::FileInfo.new.tap do |info|
          info.name = SecureRandom.uuid
          info.icon = Gio::ThemedIcon.new('folder-remote')
          info.symbolic_icon = Gio::ThemedIcon.new('folder-remote-symbolic')
          info.content_type = 'inode/directory'
          info.file_type = :shortcut
          info.set_attribute_boolean('standard::is-virtual', true)
          info.set_attribute_boolean('access::can-write', false)
          info.set_attribute_boolean('access::can-rename', false)
          info.set_attribute_boolean('access::can-delete', false)
          info.set_attribute_boolean('access::can-trash', false)
          info.set_attribute_string('standard::target-uri', uri)
        end
      end

      def set_loading(loading)
        @loading = loading
      end
  end
end
