require 'spec_helper'

describe Cauchy::Elastic::Index do
  let(:indices) { double }
  let(:server) do
    Elasticsearch::Client.new.tap do |client|
      allow(client).to receive(:indices).and_return(indices)
    end
  end
  let(:name) { 'records' }
  let(:instance) { described_class.new server, name }

  describe '.exists?' do
    subject { instance.exists? }
    before { allow(indices).to receive(:exists?).and_return(exists) }

    context 'exists' do
      let(:exists) { true }
      it { is_expected.to be_truthy }
    end

    context 'does not exist' do
      let(:exists) { false }
      it { is_expected.to be_falsy }
    end
  end

  describe '.aliases' do
    let(:aliases) { { "#{name}_123" => { 'aliases' => { name => {} } } } }
    subject { instance.aliases }
    before { allow(instance).to receive(:get).with('alias').and_return(aliases) }

    it { is_expected.to eq aliases }
  end

  describe '.mappings' do
    let(:mappings) { { 'record' => Hash } }
    subject { instance.mappings }
    before do
      allow(instance).to receive(:get).with('mapping')
        .and_return({
          name => {
            'mappings' => mappings
          }
        })
    end

    it { is_expected.to eq mappings }
  end

  describe '.settings' do
    let(:settings) { { 'settings' => Hash } }
    subject { instance.settings }
    before do
      allow(instance).to receive(:get).with('settings')
        .and_return({
          name => {
            'settings' => {
              'index' => settings
            }
          }
        })
    end

    it { is_expected.to eq settings }
  end

  describe '.alias=' do
    let(:new_alias) { 'dusty_vinyl' }
    subject { instance.alias = new_alias }

    it 'updates the alias' do
      expect(indices).to receive(:put_alias).with(index: name, name: new_alias)
      subject
    end
  end

  describe '.mappings=' do
    let(:mappings) do
      {
        dental: {
          properties: {
            title: { type: 'string', analyzer: 'snowball' }
          }
        },
        medical: {
          properties: {
            title: { type: 'string', analyzer: 'snowball' }
          }
        }
      }
    end
    subject { instance.mappings = mappings }

    it 'updates the mappings' do
      mappings.each do |type, mapping|
        expect(indices).to receive(:put_mapping)
          .with(index: name, body: mapping )
      end
      subject
    end
  end

  describe '.create' do
    let(:settings) { { settings: Hash } }
    let(:mappings) { { mappings: Hash } }

    subject do
      instance.create settings: settings, mappings: mappings
    end

    it 'creates the index' do
      expect(indices).to receive(:create)
        .with(index: name, body: { settings: settings, mappings: mappings })
      subject
    end

    context 'index exists already' do
      it 'raises an error' do
        expect(indices).to receive(:create)
          .and_raise(
            Elasticsearch::Transport::Transport::Errors::BadRequest.new('IndexAlreadyExists')
          )

        expect { subject }.to raise_error(Cauchy::Elastic::IndexAlreadyExistsError)
      end
    end
  end

  describe '.delete' do
    subject { instance.delete }

    it 'deletes the index' do
      expect(indices).to receive(:delete).with(index: name)
      subject
    end
  end
end
