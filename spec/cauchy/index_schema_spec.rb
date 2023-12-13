require 'spec_helper'

describe Cauchy::IndexSchema do

  describe 'defining a schema' do

    let(:settings) { { foo: 'bar' } }
    let(:schema) { :conversations }
    let(:type) { :conversations }
    let(:properties) { { bar: { foo: 'baz' } } }
    let(:mappings) do
      {
        properties: properties
      }
    end

    subject(:index_schema) do |ex|
      Cauchy::IndexSchema.define(schema) do
        settings do
          ex.example_group_instance.settings
        end

        mappings do
          ex.example_group_instance.mappings
        end
      end
    end

    its(:settings) { is_expected.to eq settings.stringify_keys }
    its(:mappings) { is_expected.to eq mappings.deep_stringify_keys }
    its(:types) { is_expected.to eq [ type.to_s ] }
    its(:version) do
      is_expected.to eq(
        Digest::SHA1.hexdigest(
          { settings: index_schema.settings, mappings: index_schema.mappings }.to_json
        )
      )
    end

  end

end
