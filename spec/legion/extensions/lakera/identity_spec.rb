# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Identity do
  describe '.provider_name' do
    it 'returns :lakera' do
      expect(described_class.provider_name).to eq(:lakera)
    end
  end

  describe '.provider_type' do
    it 'returns :credential' do
      expect(described_class.provider_type).to eq(:credential)
    end
  end

  describe '.capabilities' do
    it 'returns [:credentials]' do
      expect(described_class.capabilities).to eq(%i[credentials])
    end
  end

  describe '.resolve' do
    it 'returns nil' do
      expect(described_class.resolve).to be_nil
    end
  end

  describe '.provide_token' do
    context 'when Legion::Settings is not defined' do
      before do
        allow(described_class).to receive(:resolve_api_key).and_return(nil)
      end

      it 'returns nil' do
        expect(described_class.provide_token).to be_nil
      end
    end
  end
end
