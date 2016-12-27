require 'diffy'

module Cauchy
  class Migration

    CREATION_SETTINGS = %w[
      codec
      number_of_shards
    ]

    attr_accessor :schema, :new_schema

    def initialize(schema, new_schema)
      @schema = schema
      @new_schema = new_schema
    end

    def changes_mappings?
      (new_schema.types - schema.types).any? ||
        (new_schema.types & schema.types).any? do |type|
          mapping, new_mapping = schema.mapping_for(type), new_schema.mapping_for(type)
          removed_fields = mapping.keys - new_mapping.keys
          mapping.except(*removed_fields) != new_mapping
        end
    end

    def changes_existing_mappings?
      (new_schema.types & schema.types).any? do |type|
        mapping, new_mapping = schema.mapping_for(type), new_schema.mapping_for(type)
        common_fields = mapping.keys & new_mapping.keys
        mapping.slice(*common_fields) != new_mapping.slice(*common_fields)
      end
    end

    def changed_settings
      new_schema.settings.select do |name, setting|
        schema.settings[name] != setting
      end.to_h
    end

    def changes_settings?
      changed_settings.present?
    end

    def changes_creation_settings?
      schema.settings.slice(*CREATION_SETTINGS).except(*removed_settings) !=
        new_schema.settings.slice(*CREATION_SETTINGS)
    end

    def removed_settings
      schema.settings.keys - new_schema.settings.keys
    end

    def requires_reindex?
      changes_creation_settings? || changes_existing_mappings?
    end

    def up_to_date?
      !(changes_settings? || changes_mappings?)
    end

    def mappings_diffs
      (schema.mappings.keys | new_schema.mappings.keys).map do |type|
        diff = Diffy::Diff.new(
          JSON.pretty_generate(schema.mappings[type] || {}) + "\n",
          JSON.pretty_generate(new_schema.mappings[type] || {}) + "\n",
          context: 3
        )
        [type, diff]
      end.to_h
    end

    def settings_diff
      Diffy::Diff.new(
        JSON.pretty_generate(schema.settings.except(*removed_settings)) + "\n",
        JSON.pretty_generate(new_schema.settings.except(*removed_settings)) + "\n",
        context: 3
      )
    end

  end
end
