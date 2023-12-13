require 'spec_helper'

describe Cauchy::Migrator do

  let(:test_index) { :foos }

  let(:client) { Cauchy::Elastic::Client.new elasticsearch_config }

  before(:each) do
    elasticsearch.indices.delete(index: '*')
  end

  let(:initial_schema) do
    Cauchy::IndexSchema.define(test_index) do
      settings do
        {
          analysis: {
            analyzer: {
              folding: {
                tokenizer: 'standard',
                filter: [ 'lowercase', 'asciifolding' ]
              }
            }
          }
        }
      end

      mappings do
        {
          properties: {
            title: { type: 'text', analyzer: 'folding' },
          }
        }
      end
    end
  end

  let(:schema_v2) do
    Cauchy::IndexSchema.define(test_index) do
      settings do
        {
          analysis: {
            analyzer: {
              folding: {
                tokenizer: 'standard',
                filter: [ 'lowercase', 'asciifolding' ]
              }
            }
          },
          refresh_interval: -1
        }
      end

      mappings do
        {
          properties: {
            title: { type: 'text', analyzer: 'folding' },
            full_name: { type: 'text', analyzer: 'folding' }
          }
        }
      end
    end
  end

  # Requires re-index due to analysis change
  let(:schema_v3) do
    Cauchy::IndexSchema.define(test_index) do
      settings do
        {
          analysis: {
            analyzer: {
              folding: {
                tokenizer: 'standard',
                filter: [ 'lowercase' ]
              }
            }
          },
          refresh_interval: -1
        }
      end

      mappings do
        {
          properties: {
            title: { type: 'text', analyzer: 'folding' }
          }
        }
      end
    end
  end

  let(:schema_v4) do
    Cauchy::IndexSchema.define(test_index) do
      settings do
        {
          analysis: {
            analyzer: {
              folding: {
                tokenizer: 'standard',
                filter: [ 'lowercase', 'asciifolding' ]
              }
            }
          }
        }
      end

      mappings do
        {
          properties: {
            title: { type: 'text', analyzer: 'folding' },
          }
        }
      end
    end
  end

  describe 'migrate' do

    context 'initial schema' do
      it 'creates the index' do
        migrator = described_class.new(client, initial_schema)

        expect(migrator.new_index).to receive(:create)
          .with(settings: initial_schema.settings, mappings: initial_schema.mappings)
          .and_call_original

        migrator.migrate

        expect(client.index(test_index)).to be_exists

        expect(migrator.new_index.mappings).to eq initial_schema.mappings

        initial_schema.settings.each do |k, v|
          expect(migrator.new_index.settings[k]).to eq v
        end
      end
    end

    context 'migrating schemas' do
      it 'migrates the index' do
        migrator = described_class.new(client, initial_schema)
        migrator.migrate

        migrator = described_class.new(client, schema_v2)

        expect(migrator.old_index).to receive(:settings=)
          .with("refresh_interval" => "-1")
          .and_call_original

        expect(migrator.old_index).to receive(:mappings=)
          .with(schema_v2.mappings)
          .and_call_original

        migrator.migrate

        schema_v2.settings.each do |k, v|
          expect(migrator.old_index.settings[k]).to eq v
        end

        expect(migrator.old_index.mappings).to eq schema_v2.mappings
      end
    end

    context 'migration requiring closed index' do
      it 'raises an exception' do
        migrator = described_class.new(client, initial_schema)
        migrator.migrate

        migrator = described_class.new(client, schema_v4)

        expect(migrator.old_index).to_not receive(:mappings=)

        expect { migrator.migrate }.to raise_error(Cauchy::Elastic::CannotUpdateNonDynamicSettingsError)
      end

      context 'with close_index: true' do
        it 'closes index, updates, and re-opens index' do
          migrator = described_class.new(client, initial_schema)
          migrator.migrate

          migrator = described_class.new(client, schema_v4)
          expect(migrator.old_index).to receive(:close).and_call_original
          expect(migrator.old_index).to receive(:settings=).and_call_original
          expect(migrator.old_index).to receive(:open).and_call_original

          migrator.migrate close_index: true
        end
      end
    end

    context 'more than one index alias' do
      it 'raises an exception' do
        migrator = described_class.new(client, initial_schema)
        migrator.migrate

        client.index('foobaz').tap do |i|
          i.create
          i.alias = 'foos'

          migrator = described_class.new(client, schema_v2)
          expect { migrator.migrate }.to raise_error(Cauchy::MultipleIndexAliasError)

          i.delete
        end
      end
    end

  end

end
