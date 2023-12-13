require 'spec_helper'

describe Cauchy::Migration do

  let(:schema) do
    Cauchy::IndexSchema.define(:conversations) do
      settings do
        {
          analysis: {
            analyzer: {
              folding: {
                tokenizer: 'standard',
                filter: [ 'lowercase' ]
              }
            }
          }
        }
      end

      mappings do
        {
          properties: {
            title: { type: 'text', analyzer: 'folding' },
            timestamp: { type: 'date', index: 'not_analyzed' }
          }
        }
      end
    end
  end

  let(:new_schema) do
    Cauchy::IndexSchema.define(:conversations) do
      settings do
        {
          analysis: {
            analyzer: {
              folding: {
                tokenizer: 'standard',
                filter: [ 'lowercase' ]
              }
            }
          }
        }
      end

      mappings do
        {
          properties: {
            title: { type: 'text', analyzer: 'folding' },
            body: { type: 'text', analyzer: 'folding' },
            timestamp: { type: 'date', index: 'not_analyzed' }
          }
        }
      end
    end
  end

  let(:changed_schema) do
    Cauchy::IndexSchema.define(:conversations) do
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
            timestamp: { type: 'text', analyzer: 'folding' }
          }
        }
      end
    end
  end

  let(:shard_schema) do
    Cauchy::IndexSchema.define(:conversations) do
      settings do
        {
          number_of_shards: 1
        }
      end

      mappings do
        {
          properties: {
            title: { type: 'text', analyzer: 'folding' },
            body: { type: 'text', analyzer: 'folding' },
            timestamp: { type: 'text', analyzer: 'folding' }
          }
        }
      end
    end
  end

  let(:same_schema_migration) do
    described_class.new(schema, schema)
  end

  let(:new_schema_migration) do
    described_class.new(schema, new_schema)
  end

  let(:changed_schema_migration) do
    described_class.new(schema, changed_schema)
  end

  let(:shard_schema_migration) do
    described_class.new(schema, shard_schema)
  end

  describe 'changes_mappings?' do
    it 'returns true when adding a mapping' do
      expect(new_schema_migration.changes_mappings?)
        .to be true
    end

    it 'returns true when changing an existing mapping' do
      expect(changed_schema_migration.changes_mappings?)
        .to be true
    end

    it 'returns false when not changing the mapping' do
      expect(same_schema_migration.changes_mappings?)
        .to be false
    end
  end

  describe 'changes_existing_mappings?' do
    it 'returns true when changing the existing mapping' do
      expect(changed_schema_migration.changes_existing_mappings?)
        .to be true
    end

    it 'returns false when not changing the existing mapping' do
      expect(new_schema_migration.changes_existing_mappings?)
        .to be false
      expect(same_schema_migration.changes_existing_mappings?)
        .to be false
    end
  end

  describe 'changed_settings' do
    it 'returns the settings that have changed' do
      expect(changed_schema_migration.changed_settings)
        .to eq(
          "analysis"  =>  {
            "analyzer"  =>  {
              "folding" =>  {
                "filter"  =>  ["lowercase", "asciifolding"],
                "tokenizer" =>  "standard"
              }
            }
          }
        )
    end
  end

  describe 'changes_settings?' do
    it 'returns true when changing the settings' do
      expect(changed_schema_migration.changes_mappings?)
        .to be true
    end

    it 'returns false when not changing the settings' do
      expect(same_schema_migration.changes_mappings?)
        .to be false
    end
  end

  describe 'changes_creation_settings?' do
    it 'returns true when changing the creation-time settings' do
      expect(shard_schema_migration.changes_creation_settings?)
        .to be true
    end

    it 'returns false when not changing the creation-time settings' do
      expect(new_schema_migration.changes_creation_settings?)
        .to be false
      expect(same_schema_migration.changes_creation_settings?)
        .to be false
    end
  end

  describe 'requires_reindex?' do
    it 'returns true when changing the creation-time settings' do
      expect(changed_schema_migration.requires_reindex?)
        .to be true
    end

    it 'returns true when changing the existing mappings' do
      expect(shard_schema_migration.requires_reindex?)
        .to be true
    end

    it 'returns false when not changing creation-time settings or existing mappings' do
      expect(new_schema_migration.requires_reindex?)
        .to be false
      expect(same_schema_migration.requires_reindex?)
        .to be false
    end
  end

  describe 'up_to_date?' do
    it 'returns true when there are no changes to the settings or mappings' do
      expect(same_schema_migration.up_to_date?)
        .to be true
    end

    it 'returns false when there are changes to the settings or mappings' do
      expect(new_schema_migration.up_to_date?)
        .to be false
      expect(changed_schema_migration.up_to_date?)
        .to be false
    end
  end

  describe 'removed_settings' do
    before do
      new_schema.settings = {}
    end

    it 'retrieves the removed settings' do
      expect(new_schema_migration.removed_settings).to match_array ['analysis']
    end
  end

end
