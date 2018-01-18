require 'active_support/core_ext/hash'

module Cauchy
  class IndexSchema
    module Normalization

      IGNORE_SETTINGS = %w[
        creation_date
        uuid
        version
      ]

      def normalize_mapping(hash)
        hash.deep_stringify_keys.sort.map do |key, field|
          if field.key?('properties')
            field['properties'] = normalize_mapping(field['properties'])
            field['type'] ||= 'object'
          end

          if field['type'] == 'date'
            field['format'] ||= 'dateOptionalTime'
          end

          if ['boolean', 'long', 'double', 'date'].include?(field['type'])
            field.delete('analyzer')
            field['index'] ||= 'not_analyzed'
          end

          if key == 'properties'
            field = normalize_mapping(field)
          else
            field = normalize_value(field)
          end

          [key, field]
        end.to_h
      end

      def normalize_settings(hash)
        normalize_value(hash.deep_stringify_keys.except(*IGNORE_SETTINGS))
      end

      def normalize_value(value)
        case value
        when Hash
          value.sort.map {|key, v| [key, normalize_value(v)] }.to_h
        when Numeric
          value.to_s
        else
          value
        end
      end

    end
  end
end
