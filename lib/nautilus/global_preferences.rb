# frozen_string_literal: true

require 'json'
require 'fileutils'

module Nautilus
  # GlobalPreferences holds the keys of upstream's GSettings schemas.
  #
  # Ported from data/org.gnome.nautilus.gschema.xml and
  # src/nautilus-global-preferences.c. Upstream reads these through GSettings,
  # which needs the compiled schema installed into the system's
  # glib-2.0/schemas directory; a Gio::Settings for a schema that is not
  # installed aborts the process, so requiring an install step to run the app
  # from a checkout is not an option. The same schemas, keys, defaults and
  # enum value sets are backed by one JSON file under XDG_CONFIG_HOME instead,
  # and `changed::<key>` is served by Schema#connect.
  class GlobalPreferences
    # The <enum> elements of the schema file, in their declared order, so a
    # key's value can be validated and mapped to and from its integer nick.
    ENUMS = {
      'speed-tradeoff'          => %w[always local-only never],
      'click-policy'            => %w[single double],
      'date-time-format'        => %w[simple detailed],
      'activation-choice'       => %w[launch display ask],
      'folder-view'             => %w[list-view icon-view],
      'sort-order'              => %w[name size type mtime atime btime starred],
      'grid-zoom-level'         => %w[small small-plus medium large extra-large],
      'list-zoom-level'         => %w[small medium large],
      'search-filter-time-type' => %w[last_modified last_used created],
      'compression-format'      => %w[zip tar.xz 7z encrypted_zip],
    }.freeze

    # Aliases declared in the schema file, kept so a config written by an older
    # version (or by dconf) still resolves to a value the app understands.
    ALIASES = {
      'local_only'        => 'local-only',
      'modification_date' => 'mtime',
      'icon_view'         => 'icon-view',
      'compact_view'      => 'icon-view',
      'compact-view'      => 'icon-view',
      'list_view'         => 'list-view',
      'standard'          => 'small-plus',
      'larger'            => 'extra-large',
      'largest'           => 'extra-large',
    }.freeze

    # Every key of every schema: its default and, for enum keys, the enum it
    # draws its values from.
    SCHEMAS = {
      'preferences'      => {
        'always-use-location-entry'     => { default: false },
        'recursive-search'              => { default: 'local-only', enum: 'speed-tradeoff' },
        'search-filter-time-type'       => { default: 'last_modified', enum: 'search-filter-time-type' },
        'show-delete-permanently'       => { default: false },
        'show-create-link'              => { default: false },
        'show-directory-item-counts'    => { default: 'local-only', enum: 'speed-tradeoff' },
        'click-policy'                  => { default: 'double', enum: 'click-policy' },
        'mouse-use-extra-buttons'       => { default: true },
        'mouse-forward-button'          => { default: 9 },
        'mouse-back-button'             => { default: 8 },
        'show-image-thumbnails'         => { default: 'local-only', enum: 'speed-tradeoff' },
        'thumbnail-limit'               => { default: 50 },
        'default-sort-order'            => { default: 'name', enum: 'sort-order' },
        'default-sort-in-reverse-order' => { default: false },
        'default-folder-viewer'         => { default: 'icon-view', enum: 'folder-view' },
        'show-hidden-files'             => { default: false },
        'migrated-gtk-settings'         => { default: false },
        'open-folder-on-dnd-hover'      => { default: true },
        'fts-enabled'                   => { default: true },
        'date-time-format'              => { default: 'simple', enum: 'date-time-format' },
      },
      # Upstream's show-hidden-files key is deprecated and ignored; the two
      # keys below live in org.gtk.Settings.FileChooser, which nautilus reads
      # directly for "Show Hidden Files" and "Sort Folders Before Files".
      'gtk-file-chooser' => {
        'show-hidden'            => { default: false },
        'sort-directories-first' => { default: true },
      },
      'compression'      => {
        'default-compression-format' => { default: 'zip', enum: 'compression-format' },
      },
      'icon-view'        => {
        'captions'           => { default: %w[none none none] },
        'default-zoom-level' => { default: 'medium', enum: 'grid-zoom-level' },
      },
      'list-view'        => {
        'default-zoom-level'      => { default: 'medium', enum: 'list-zoom-level' },
        'default-visible-columns' => { default: %w[name size date_modified] },
        'default-column-order'    => {
          default: %w[
            name size type owner group permissions mime_type where
            date_modified date_modified_with_time date_accessed date_created
            recency starred
          ],
        },
        'use-tree-view'           => { default: false },
      },
      'window-state'     => {
        'initial-size'              => { default: [890, 550] },
        'maximized'                 => { default: false },
        'initial-size-file-chooser' => { default: [890, 550] },
      },
    }.freeze

    # One schema's worth of keys. Mirrors the slice of the GSettings API the
    # app actually uses: value access, enum access and per-key change signals.
    class Schema
      def initialize(name, keys, store)
        @name = name
        @keys = keys
        @store = store
        @handlers = {}
      end

      attr_reader :name

      def key?(key) = @keys.key?(key.to_s)

      def default(key) = @keys.fetch(key.to_s).fetch(:default)

      def [](key)
        @store.read(@name, key.to_s).then do |stored|
          coerce(key.to_s, stored)
        end
      end

      def []=(key, value)
        @store.write(@name, key.to_s, coerce(key.to_s, value))
        notify(key.to_s)
        value
      end

      # The integer a GSettings enum key would report, from the value's
      # position in the enum's declared order.
      def enum(key) = enum_values(key).index(self[key]).to_i

      def enum_values(key) = ENUMS.fetch(@keys.fetch(key.to_s).fetch(:enum))

      def enum?(key) = @keys.fetch(key.to_s).key?(:enum)

      def boolean?(key) = [true, false].include?(default(key))

      def toggle(key)
        self[key] = !self[key]
      end

      # Stands in for `g_signal_connect (settings, "changed::key", ...)`.
      def connect(key, &handler)
        (@handlers[key.to_s] ||= []) << handler
        handler
      end

      def disconnect(key, handler)
        (@handlers[key.to_s] || []).delete(handler)
      end

      def notify(key)
        (@handlers[key.to_s] || []).each { |handler| handler.call(self, key.to_s) }
      end

      private

        # Keeps an out-of-range enum nick, or a value of the wrong class, from
        # reaching the widgets: GSettings would have rejected it at write time.
        def coerce(key, value)
          @keys.fetch(key).then do |spec|
            if spec.key?(:enum)
              resolve_enum(spec, value)
            else
              resolve_plain(spec, value)
            end
          end
        end

        def resolve_enum(spec, value)
          ENUMS.fetch(spec.fetch(:enum)).then do |values|
            ALIASES.fetch(value.to_s, value.to_s).then do |nick|
              if values.include?(nick)
                nick
              else
                spec.fetch(:default)
              end
            end
          end
        end

        def resolve_plain(spec, value)
          spec.fetch(:default).then do |fallback|
            if same_kind?(value, fallback)
              value
            else
              fallback
            end
          end
        end

        # true and false are different classes in Ruby, so a boolean key has
        # to be matched on both of them rather than on the default's class.
        def same_kind?(value, fallback)
          if [true, false].include?(fallback)
            [true, false].include?(value)
          else
            value.instance_of?(fallback.class)
          end
        end
    end

    # The JSON file the schemas share, one object per schema.
    class Store
      def initialize(path)
        @path = path
        @values = read_file
      end

      attr_reader :path

      def read(schema, key)
        @values.fetch(schema, {}).fetch(key, nil).then do |stored|
          if stored.nil?
            SCHEMAS.fetch(schema).fetch(key).fetch(:default)
          else
            stored
          end
        end
      end

      def write(schema, key, value)
        (@values[schema] ||= {})[key] = value
        FileUtils.mkdir_p(::File.dirname(@path))
        ::File.write(@path, JSON.pretty_generate(@values))
        value
      end

      private

        def read_file
          if ::File.exist?(@path)
            parse_file
          else
            {}
          end
        end

        def parse_file
          JSON.parse(::File.read(@path))
        rescue JSON::ParserError => error
          warn("Error parsing #{@path}: #{error.message}")
          {}
        end
    end

    def self.instance = @instance ||= new

    def initialize(path: nil)
      @store = Store.new(path || self.class.default_path)
      @schemas = SCHEMAS.each_with_object({}) do |(name, keys), schemas|
        schemas[name] = Schema.new(name, keys, @store)
      end
    end

    def self.default_path
      ::File.join(
        ENV.fetch('XDG_CONFIG_HOME', ::File.expand_path('~/.config')),
        'ruby-nautilus',
        'settings.json',
      )
    end

    def location = @store.path

    def schema(name) = @schemas.fetch(name.to_s)

    def preferences = schema('preferences')
    def compression = schema('compression')
    def icon_view = schema('icon-view')
    def list_view = schema('list-view')
    def window_state = schema('window-state')
    def file_chooser = schema('gtk-file-chooser')

    # Restores the geometry recorded by the previous run, the way
    # nautilus_window_constructed() applies the window-state schema.
    def apply_to(window)
      window_state['initial-size'].then do |(width, height)|
        window.set_default_size(width, height)
      end
      if window_state['maximized']
        window.maximize
      end
    end

    # Records the geometry, skipping the size while maximized so the restored
    # size is the one the user actually chose.
    def remember(window)
      window_state['maximized'] = window.maximized?
      unless window.maximized?
        window_state['initial-size'] = [window.default_width, window.default_height]
      end
    end
  end
end
