require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/string/inflections'
require 'active_support/hash_with_indifferent_access'
require 'thor'
require 'yaml'

require 'cauchy'

module Cauchy

  class Cli < Thor
    include Thor::Actions

    default_path = ENV.fetch('CAUCHY_PATH', '.')

    class_option :path, default: default_path,
      banner: 'project path', desc: 'CAUCHY_PATH env var will be recognized'

    desc 'init', 'Create cauchy project directories'
    def init
      init_project
    end

    desc 'new [SCHEMA_NAME]', 'Create an empty index schema file'
    def new(name)
      verify_project!
      generate_schema name
    end

    desc 'apply [SCHEMA_NAME]', 'Applys a schema'
    method_option :reindex, default: false, type: :boolean, desc: 'Reindex data, if required'
    method_option :close_index, default: false, type: :boolean, desc: 'Close index to update non-dynamic settings'
    def apply(schema_name = nil)
      verify_project!
      Migrator.migrate(
        client, schema_path, schema_name,
        options.slice('reindex', 'close_index').symbolize_keys
      )
    rescue Elastic::CannotUpdateNonDynamicSettingsError => e
      Cauchy.logger.warn e.to_s
      Cauchy.logger.warn 'Provide --close-index in order to perform this update'
    rescue MigrationError => e
      Cauchy.logger.warn e.to_s
    end

    desc 'status [SCHEMA_NAME]', 'Displays index status'
    def status(schema_name = nil)
      verify_project!
      Migrator.status(client, schema_path, schema_name)
    rescue MigrationError => e
      Cauchy.logger.warn e.to_s
    end

    desc 'version', 'Displays the version number'
    def version
      Cauchy.logger.info "Couchy v#{Cauchy::VERSION}"
    end

    private

    def project_path
      @project_path ||= File.expand_path options['path']
    end

    def config_path
      @config_path ||= File.join project_path, 'config.yml'
    end

    def schema_path(schema_file = nil)
      File.join *[project_path, 'schema', schema_file].compact
    end

    def client
      @client ||= Elastic::Client.new(config)
    end

    def config
      @config ||= begin
        if File.exists?(config_path)
          YAML.load_file(config_path).deep_symbolize_keys
        else
          { url: ENV.fetch('ELASTICSEARCH_URL', 'localhost:9200') }
        end
      end
    end

    def yaml_config

    end

    def normalize_schema_name(name)
      name.gsub(/[^a-z0-9\-]+/i, '_').downcase
    end

    def verify_project!
      unless Dir.exists? schema_path
        Cauchy.logger.fatal "Unable to locate schema directory #{schema_path}"
        Cauchy.logger.info 'Did you setup a project with `cauchy init`?'
        exit
      end
    end

    def init_project
      unless Dir.exists? schema_path
        Cauchy.logger.debug "Creating schema directory at #{schema_path}"
        FileUtils.mkdir_p schema_path
      end

      unless File.exists? config_path
        Cauchy.logger.debug "Creating config file at #{config_path}"
        File.open(config_path, 'w+') { |f| f.print <<-YAML }
# Supports elasticsearch/transport options. See: http://www.rubydoc.info/gems/elasticsearch-transport
# This file is optional, you can also set ELASTICSEARCH_URL in your environment
hosts:
  - host: localhost
    port: 9200
    scheme: http
YAML
      end

      Cauchy.logger.info "\nWant to run cauchy from anywhere? Add the following to your shell config:"
      Cauchy.logger.debug "export CAUCHY_PATH=#{project_path}"
    end

    def generate_schema(name)
      name = normalize_schema_name(name)
      path = schema_path("#{name}.rb")

      if File.exists? path
        return unless yes? "Schema file exists at #{path}, overwrite? (y/n)?"
      end

      Cauchy.logger.info "Creating a new schema `#{name}` at #{path}"

      File.open(path, 'w+') { |f| f.print <<-RB }
Cauchy::IndexSchema.define(:#{name}) do

  settings do
    # {
    #   number_of_replicas: 2
    # }
  end

  mappings do
    # {
    #   #{name.singularize}: {
    #     properties: {
    #       name: { type: 'string' }
    #     }
    #   }
    # }
  end

end
RB
    end
  end
end
