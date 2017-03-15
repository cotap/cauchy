require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/object/blank'
require 'ruby-progressbar'
require 'json'

require 'cauchy/index_schema'
require 'cauchy/migration'

module Cauchy

  class MigrationError < StandardError
  end

  class UnknownIndexSchemaError < MigrationError
    def initialize(name)
      super("No index schema defined for \"#{name}\"")
    end
  end

  class MultipleIndexAliasError < MigrationError
    def initialize(name)
      super("Multiple index aliases found for \"#{name}\"")
    end
  end

  class NoIndexSchemasError < MigrationError
    def initialize
      super("No index schemas defined")
    end
  end

  class Migrator

    class << self

      def migrate(client, index_paths = nil, target_index = nil, options = {})
        with_schemas(index_paths, target_index) do |schema|
          new(client, schema).migrate options
        end
      end

      def status(client, index_paths = nil, target_index = nil)
        with_schemas(index_paths, target_index) do |schema|
          new(client, schema).status
        end
      end

      private

      def with_schemas(index_paths, target_index = nil)
        found_target = false
        IndexSchema.load_schemas(index_paths)

        raise NoIndexSchemasError unless IndexSchema.schemas.any?

        IndexSchema.schemas.each do |index_alias, schema|
          if target_index.nil? || target_index == index_alias
            found_target = true
            yield schema
          end
        end

        raise UnknownIndexSchemaError, target_index unless found_target
      end

    end

    attr_reader :client, :schema

    def initialize(client, schema)
      @client = client
      @schema = schema
    end

    delegate :index_alias, :version, to: :schema

    def new_index_name
      "#{index_alias}_#{version}"
    end

    def new_index
      @new_index ||= client.index(new_index_name)
    end

    def old_index
      @old_index ||= client.index(resolve_index)
    end

    def migration
      @migration ||= Migration.new(old_schema, schema)
    end

    def migrate(options = {})
      raise MultipleIndexAliasError, index_alias if index_aliases.keys.length > 1

      if options[:reindex] || !old_index.exists?
        return reindex(options)
      end

      if migration.up_to_date?
        log 'Index is up-to-date.'
        return true
      end

      if migration.requires_reindex?
        log migration_diff, :unknown
        log 'Requires reindexing!', :warn
        return false
      end

      if migration.changes_settings?
        log 'Updating index settings... ' do
          begin
            old_index.close if options[:close_index]
            old_index.settings = migration.changed_settings
          rescue Elastic::CannotUpdateNonDynamicSettingsError
            log migration_diff, :unknown
            raise
          ensure
            old_index.open if options[:close_index]
          end
          'done.'
        end
      end

      if migration.changes_mappings?
        log 'Updating index mappings... ' do
          old_index.mappings = migration.new_schema.mappings
          'done.'
        end
      end
    end

    def reindex(options = {})
      if old_index.exists?
        if migration.up_to_date?
          log 'Index is up-to-date.'
          return true
        elsif !migration.requires_reindex?
          log 'Does not require reindexing... skipping.'
          return false
        end
      end

      begin
        log "Creating new index #{new_index_name}"
        new_index.create settings: schema.settings, mappings: schema.mappings
      rescue Elastic::IndexAlreadyExistsError
        log "Index #{new_index_name} already exists, continuing...", :warn
      end

      reindex_data if old_index.exists?

      cleanup options

      true
    end

    def reindex_data
      log 'Reindexing...'
      progress_bar = nil
      old_index.scroll do |documents, total|
        docs = documents.map do |h|
          {
            index: {
              _index: new_index.name,
              _type: h['_type'],
              _id: h['_id'],
              data: h['_source']
            }
          }
        end

        client.bulk docs

        progress_bar ||= ProgressBar.create(total: total, throttle_rate: 0.1, format: '%a |%B| %e')
        progress_bar.progress += docs.size
      end
    end

    def status
      if migration.up_to_date?
        log 'Index is up-to-date.'
      else
        log migration_diff, :unknown
        log 'Requires reindexing!', :warn if migration.requires_reindex?
      end
    end

    def inspect
      "#<#{self.class.name}"\
        " index_alias=\"#{index_alias}\""\
        " version=\"#{version[0..6]}\">"
    end

    def old_schema
      @old_schema ||= begin
        IndexSchema.new(index_alias).tap do |schema|
          schema.mappings = old_index.mappings
          schema.settings = old_index.settings
        end
      end
    end

    private

    def cleanup(options)
      log "Aliasing #{new_index.name} => #{index_alias}"
      if old_index.name == index_alias
        old_index.delete if old_index.exists?
        new_index.alias = index_alias
      else
        client.update_aliases({
          actions: [
            { add:    { alias: index_alias, index: new_index.name } },
            { remove: { alias: index_alias, index: old_index.name } }
          ]
        })
        old_index.delete if options.fetch :cleanup, true
      end
    end

    def migration_diff
      mappings_diff = migration.mappings_diffs.map do |type, diff|
          diff = diff.to_s(:color).rstrip
         "Mapping type=#{type}:\n" + diff if diff.present?
      end.compact.join("\n")

      settings_diff = migration.settings_diff.to_s(:color).rstrip
      settings_diff = "Settings:\n" + settings_diff if settings_diff.present?

      [mappings_diff, settings_diff].select(&:present?).join("\n\n")
    end

    def resolve_index
      index_aliases.keys.first || index_alias
    end

    def index_aliases
      client.index(index_alias).aliases || {}
    end

    def log(msg, method = :info, &block)
      Cauchy.logger.send(method, msg)
      Cauchy.logger.send(method, block.call) if block_given?
    end

  end
end
