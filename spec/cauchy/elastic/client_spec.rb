require 'spec_helper'

describe Cauchy::Elastic::Client do

  let(:instance) do
    described_class.new elasticsearch_config
  end

  let(:server) { instance.server }

  describe '.index' do
    let(:name) { 'records' }
    subject(:index) { instance.index name }

    its(:class) { is_expected.to eq Cauchy::Elastic::Index }
    its(:name) { is_expected.to eq name }
  end

  describe '.bulk' do
    let(:body) { [ { index: { _index: 'records', _type: 'record', id: 1 } } ] }
    subject(:bulk) { instance.bulk body }

    it 'calls to perform a bulk operation' do
      expect(server).to receive(:bulk).with(body: body)
      bulk
    end
  end

  describe '.update_aliases' do
    let(:body) do
      {
        actions: [
          { add: { index: 'logs-2013-06', alias: 'year-2013' } },
          { add: { index: 'logs-2013-05', alias: 'year-2013' } }
        ]
      }
    end
    subject(:update_aliases) { instance.update_aliases body }

    it 'calls to perform a bulk operation' do
      indices = double
      expect(indices).to receive(:update_aliases).with(body: body)
      expect(server).to receive(:indices).and_return(indices)
      update_aliases
    end
  end

end
