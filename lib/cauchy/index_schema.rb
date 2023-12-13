require 'cauchy/index_schema/normalization'

module Cauchy
  class IndexSchema

    include Normalization

    @@schemas = {}

    class << self

      def define(index_alias, &block)
        index_alias = index_alias.to_s
        schemas[index_alias] = new(index_alias).tap { |s| s.define(&block) }
      end

      def load_schemas(paths)
        Dir[*Array(paths).map { |p| "#{p}/**/*.rb" }].each { |f| load f }
      end

      def schemas
        @@schemas
      end

      def schemas=(schemas)
        @@schemas = schemas
      end

    end

    attr_accessor :index_alias

    def initialize(index_alias)
      @index_alias = index_alias
    end

    def define(&block)
      instance_eval(&block)
    end

    def mappings(&block)
      self.mappings = block.call || {} if block_given?
      @mappings || {}
    end

    def mappings=(value)
      @mappings = value.map do |type, mapping|
        [type.to_s, normalize_mapping(mapping)]
      end.to_h
    end

    def mapping_properties
      return unless mappings.key?('properties')
      mappings['properties']
    end

    def settings(&block)
      self.settings = block.call || {} if block_given?
      @settings || {}
    end

    def settings=(value)
      @settings = normalize_settings(value)
    end

    def types
      Array.wrap(index_alias)
    end

    def version
      @version ||= Digest::SHA1.hexdigest(
        { settings: settings, mappings: mappings }.to_json
      )
    end

  end
end
