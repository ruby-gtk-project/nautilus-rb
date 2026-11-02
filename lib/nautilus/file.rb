# frozen_string_literal: true

require 'adwaita'
require 'etc'
require 'json'
require 'fileutils'
require 'time'
require_relative 'date_utilities'
require_relative 'global_preferences'

module Nautilus
  # File is one file or folder, with the attributes the views and the
  # properties labels read off it.
  #
  # Stands in for the model layer of src/nautilus-file.c, which is an
  # attribute cache over GIO with its own asynchronous monitors. What the
  # widgets need from it is the set of named attributes the list-view columns
  # ask for (see ColumnUtilities), the display name, the icon, and the
  # comparison functions the sorters use; those are what this holds, read from
  # one Gio::FileInfo. It is a GLib::Object because the views put it in a
  # Gio::ListStore.
  class File < GLib::Object
    type_register

    # The attributes one query_info() call has to fetch to fill every column.
    ATTRIBUTES = [
      'standard::name',
      'standard::display-name',
      'standard::type',
      'standard::size',
      'standard::content-type',
      'standard::fast-content-type',
      'standard::is-hidden',
      'standard::is-backup',
      'standard::is-symlink',
      'standard::symlink-target',
      'standard::icon',
      'standard::target-uri',
      'access::can-write',
      'access::can-execute',
      'access::can-rename',
      'access::can-trash',
      'access::can-delete',
      'owner::user',
      'owner::group',
      'unix::mode',
      'unix::uid',
      'unix::gid',
      'time::modified',
      'time::access',
      'time::created',
      'trash::deletion-date',
      'trash::orig-path',
      'recent::modified',
    ].join(',').freeze

    STARRED_STORE = ::File.join(
      ENV.fetch('XDG_DATA_HOME', ::File.expand_path('~/.local/share')),
      'ruby-nautilus',
      'starred.json',
    )

    def self.for_location(location, info: nil)
      new(location, info || location.query_info(ATTRIBUTES, :none, nil))
    end

    def self.for_path(path) = for_location(Gio::File.new_for_path(path))

    # The starred set upstream keeps in its tag manager's database.
    def self.starred_uris
      @starred_uris ||= read_starred
    end

    def self.read_starred
      if ::File.exist?(STARRED_STORE)
        JSON.parse(::File.read(STARRED_STORE))
      else
        []
      end
    rescue JSON::ParserError
      []
    end

    def self.write_starred
      FileUtils.mkdir_p(::File.dirname(STARRED_STORE))
      ::File.write(STARRED_STORE, JSON.generate(starred_uris))
    end

    def initialize(location, info)
      super()
      @location = location
      @info = info
    end

    attr_reader :location, :info

    def uri = @location.uri
    def path = @location.path
    def name = @info.name
    def display_name = @info.display_name || @info.name
    def parent = @location.parent

    def directory? = @info.file_type == :directory
    def symlink? = @info.symlink?
    def hidden? = @info.hidden? || @info.backup?
    def symlink_target = @info.symlink_target
    def target_uri = string_attribute('standard::target-uri')

    def can_write? = attribute_boolean('access::can-write')
    def can_execute? = attribute_boolean('access::can-execute')
    def can_rename? = attribute_boolean('access::can-rename')
    def can_trash? = attribute_boolean('access::can-trash')
    def can_delete? = attribute_boolean('access::can-delete')

    def in_trash? = uri.start_with?('trash:')
    def in_recent? = uri.start_with?('recent:')

    def icon = @info.icon

    def content_type
      @info.content_type || string_attribute('standard::fast-content-type') || 'application/octet-stream'
    end

    def archive? = ARCHIVE_TYPES.include?(content_type)

    ARCHIVE_TYPES = %w[
      application/zip
      application/x-7z-compressed
      application/x-tar
      application/x-compressed-tar
      application/x-xz-compressed-tar
      application/x-bzip-compressed-tar
      application/gzip
      application/x-rar
    ].freeze

    # --- The named attributes the list-view columns ask for -----------------

    def attribute(name)
      case name.to_s
      when 'name' then display_name
      when 'size' then size_string
      when 'type' then type_string
      when 'detailed_type' then detailed_type_string
      when 'date_modified' then date_string(date_modified)
      when 'date_accessed' then date_string(date_accessed)
      when 'date_created' then date_string(date_created)
      when 'recency' then date_string(recency)
      when 'trashed_on' then date_string(trashed_on)
      when 'trash_orig_path' then trash_orig_path.to_s
      when 'owner' then owner_string
      when 'group' then group_string
      when 'permissions' then permissions_string
      when 'starred' then starred?.to_s
      when 'search_relevance' then search_relevance.to_s
      else ''
      end
    end

    def size = @info.size.to_i

    # nautilus_file_get_size_as_string(): a folder reports its item count, a
    # file its byte size.
    def size_string
      if directory?
        item_count_string
      else
        GLib.format_size(size)
      end
    end

    def item_count_string
      item_count.then do |count|
        if count.nil?
          '—'
        elsif count == 1
          '1 item'
        else
          "#{count} items"
        end
      end
    end

    # nautilus_file_get_directory_item_count(): the count is only computed
    # when the show-directory-item-counts preference allows it for this
    # location, since counting means walking the folder.
    def item_count
      if directory? && count_items?
        count_children
      end
    end

    def count_items?
      case GlobalPreferences.instance.preferences['show-directory-item-counts']
      when 'never' then false
      when 'local-only' then !path.nil?
      else true
      end
    end

    def type_string
      if directory?
        'Folder'
      else
        self.class.description_for(content_type)
      end
    end

    # The detailed type spells the MIME type out beside its description.
    def detailed_type_string
      if directory?
        'Folder'
      else
        "#{self.class.description_for(content_type)} (#{content_type})"
      end
    end

    # g_content_type_get_description() has no Ruby binding — Gio::ContentType
    # only exposes guess() and registered() — so the descriptions upstream
    # gets from the shared MIME database are derived from the MIME type here:
    # the common types are named the way the MIME database names them, and
    # anything else is built from its subtype and media type.
    DESCRIPTIONS = {
      'inode/directory'                 => 'Folder',
      'application/octet-stream'        => 'Unknown',
      'text/plain'                      => 'Plain Text Document',
      'text/html'                       => 'HTML Document',
      'text/markdown'                   => 'Markdown Document',
      'text/csv'                        => 'CSV Document',
      'application/pdf'                 => 'PDF Document',
      'application/zip'                 => 'Zip Archive',
      'application/gzip'                => 'Gzip Archive',
      'application/x-tar'               => 'Tar Archive',
      'application/x-compressed-tar'    => 'Compressed Tar Archive',
      'application/x-xz-compressed-tar' => 'XZ Compressed Tar Archive',
      'application/x-7z-compressed'     => '7-Zip Archive',
      'application/json'                => 'JSON Document',
      'application/x-ruby'              => 'Ruby Script',
      'application/x-shellscript'       => 'Shell Script',
      'application/x-desktop'           => 'Desktop Entry',
      'application/x-executable'        => 'Program',
      'application/x-sharedlib'         => 'Shared Library',
    }.freeze

    MEDIA_NAMES = {
      'audio' => 'Audio',
      'video' => 'Video',
      'image' => 'Image',
      'text'  => 'Document',
      'font'  => 'Font',
    }.freeze

    def self.description_for(content_type)
      DESCRIPTIONS.fetch(content_type) { derived_description(content_type) }
    end

    def self.derived_description(content_type)
      content_type.to_s.split('/').then do |(media, subtype)|
        humanize_subtype(subtype.to_s).then do |name|
          "#{name} #{MEDIA_NAMES.fetch(media, 'File')}"
        end
      end
    end

    def self.humanize_subtype(subtype)
      subtype.delete_prefix('x-').split(/[-+.]/).map(&:capitalize).join(' ')
    end

    def date_modified = time_attribute('time::modified')
    def date_accessed = time_attribute('time::access')
    def date_created = time_attribute('time::created')
    def recency = time_attribute('recent::modified')

    def trashed_on
      string_attribute('trash::deletion-date').then do |value|
        unless value.nil?
          Time.parse(value)
        end
      end
    rescue ArgumentError
      nil
    end

    def trash_orig_path = string_attribute('trash::orig-path')

    def owner_string = user_name_with_id(unix_attribute('unix::uid'), string_attribute('owner::user'))

    def group_string = user_name_with_id(unix_attribute('unix::gid'), string_attribute('owner::group'))

    # The textual mode line ls(1) prints, which is what the permissions
    # column shows.
    def permissions_string
      unix_attribute('unix::mode').then do |mode|
        if mode.nil?
          '—'
        else
          mode_string(mode)
        end
      end
    end

    def starred? = self.class.starred_uris.include?(uri)

    def starred=(starred)
      if starred
        self.class.starred_uris.push(uri).uniq!
      else
        self.class.starred_uris.delete(uri)
      end
      self.class.write_starred
      starred
    end

    # Search results carry a relevance rank; anything else ranks at zero.
    attr_writer :search_relevance

    def search_relevance = @search_relevance.to_i

    # --- Comparison, as nautilus_file_compare_for_sort() does ---------------

    def sort_key(attribute)
      case attribute.to_s
      when 'size' then size
      when 'type', 'detailed_type' then type_string.downcase
      when 'date_modified' then date_modified.to_i
      when 'date_accessed' then date_accessed.to_i
      when 'date_created' then date_created.to_i
      when 'recency' then recency.to_i
      when 'trashed_on' then trashed_on.to_i
      when 'starred' then starred_sort_key
      when 'search_relevance' then search_relevance
      else collation_key
      end
    end

    def starred_sort_key
      if starred?
        1
      else
        0
      end
    end

    # Case-insensitive, digits compared as numbers, which is the order
    # g_utf8_collate_key_for_filename() gives.
    def collation_key
      display_name.downcase.scan(/\d+|\D+/).map do |chunk|
        if chunk.match?(/\A\d+\z/)
          chunk.to_i.to_s.rjust(12, '0')
        else
          chunk
        end
      end.join
    end

    private

      def attribute_boolean(name)
        @info.has_attribute?(name) && @info.get_attribute_boolean(name)
      rescue StandardError
        false
      end

      def string_attribute(name)
        if @info.has_attribute?(name)
          @info.get_attribute_as_string(name)
        end
      rescue StandardError
        nil
      end

      def unix_attribute(name)
        if @info.has_attribute?(name)
          @info.get_attribute_uint32(name)
        end
      rescue StandardError
        nil
      end

      def time_attribute(name)
        if @info.has_attribute?(name)
          seconds_to_time(@info.get_attribute_uint64(name))
        end
      rescue StandardError
        nil
      end

      # A zero timestamp means "not recorded", not "the epoch".
      def seconds_to_time(seconds)
        unless seconds.to_i.zero?
          Time.at(seconds)
        end
      end

      def date_string(time)
        if time.nil?
          '—'
        else
          DateUtilities.to_str(time)
        end
      end

      def user_name_with_id(id, name)
        if name.nil? && id.nil?
          '—'
        elsif name.nil?
          id.to_s
        elsif id.nil?
          name
        else
          "#{name} (#{id})"
        end
      end

      def mode_string(mode)
        [
          file_type_character,
          permission_triplet((mode >> 6) & 7),
          permission_triplet((mode >> 3) & 7),
          permission_triplet(mode & 7),
        ].join
      end

      def file_type_character
        if directory?
          'd'
        elsif symlink?
          'l'
        else
          '-'
        end
      end

      def permission_triplet(bits)
        [
          read_character(bits),
          write_character(bits),
          execute_character(bits),
        ].join
      end

      def read_character(bits)
        if (bits & 4).zero?
          '-'
        else
          'r'
        end
      end

      def write_character(bits)
        if (bits & 2).zero?
          '-'
        else
          'w'
        end
      end

      def execute_character(bits)
        if (bits & 1).zero?
          '-'
        else
          'x'
        end
      end

      # GLocalFileEnumerator is not enumerable in the Ruby bindings; the only
      # way through it is next_file() until it returns nil.
      def count_children
        @location.enumerate_children('standard::name', :none, nil).then do |enumerator|
          count = 0
          while enumerator.next_file(nil)
            count += 1
          end
          enumerator.close
          count
        end
      rescue GLib::Error
        nil
      end
  end
end
