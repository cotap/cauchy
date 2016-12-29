require 'spec_helper'

describe Cauchy::IndexSchema::Normalization do

  let(:klass) do
    Class.new do
      class << self
        include Cauchy::IndexSchema::Normalization
      end
    end
  end

  describe 'normalize_mapping' do
    let(:input) do
      {
        conversation: {
          properties: {
            title: { type: 'string', analyzer: 'folding' },
            timestamp: { type: 'date', index: 'not_analyzed' },
            talker_ids: { type: 'long' },
            organization_id: { type: 'long', index: 'not_analyzed' },
            official: { type: 'boolean', analyzer: 'bar' }
          }
        }
      }
    end

    subject(:normalize_mapping) { klass.normalize_mapping input }

    it 'appends the object type to top-level elements' do
      expect(normalize_mapping['conversation']['type']).to eq 'object'
    end

    it 'formats date fields' do
      ts = normalize_mapping['conversation']['properties']['timestamp']
      expect(ts['format']).to eq 'dateOptionalTime'
    end

    it 'formats the unanalyzable fields correctly' do
      official = normalize_mapping['conversation']['properties']['official']
      expect(official['index']).to eq 'not_analyzed'
      expect(official.keys).to_not include('analyzer')
    end
  end

  describe 'normalize_settings' do
    it 'stringifies the keys' do
      expect(klass.normalize_settings({ foo: 'bar' }))
        .to eq({ 'foo' => 'bar' })
    end

    it 'filters ignored keys' do
      expect(klass.normalize_settings({
        foo: 'bar',
        creation_date: 'noaw',
        uuid: 'i-am-the-upsetter',
        version: '4.2.0'
      })).to eq({ 'foo' => 'bar' })
    end

    it 'normalizes the values' do
      expect(klass).to receive(:normalize_value).twice # Twice because of the hash
        .and_call_original

      expect(klass.normalize_settings({ foo: 123 }))
        .to eq({ 'foo' => '123' })
    end
  end

  describe 'normalize_value' do
    it 'converts numerics to strings' do
      expect(klass.normalize_value(123)).to eq '123'
    end

    it 'does nothign to non-numerics' do
      expect(klass.normalize_value('foo')).to eq 'foo'
      expect(klass.normalize_value({ foo: 'bar', baz: [1,2,3] }))
        .to eq({ foo: 'bar', baz: [1,2,3] })
    end

    it 'recursively operates on hashes' do
      expect(klass.normalize_value({ foo: { bar: 123 }, baz: 456 }))
        .to eq({ foo: { bar: '123' }, baz: '456' })
    end
  end

end
