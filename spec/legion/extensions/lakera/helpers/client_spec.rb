# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Helpers::Client do
  describe '.client' do
    subject(:conn) { described_class.client(api_key: 'lk_test_key') }

    it 'returns a Faraday connection' do
      expect(conn).to be_a(Faraday::Connection)
    end

    it 'sets the default host' do
      expect(conn.url_prefix.to_s).to eq('https://api.lakera.ai/')
    end

    it 'sets Bearer authorization header' do
      expect(conn.headers['Authorization']).to eq('Bearer lk_test_key')
    end

    it 'sets Content-Type header' do
      expect(conn.headers['Content-Type']).to eq('application/json')
    end

    it 'sets default timeout' do
      expect(conn.options.timeout).to eq(30)
    end

    it 'sets default open_timeout' do
      expect(conn.options.open_timeout).to eq(10)
    end

    it 'accepts custom timeout values' do
      conn = described_class.client(api_key: 'lk_test', timeout: 60, open_timeout: 20)
      expect(conn.options.timeout).to eq(60)
      expect(conn.options.open_timeout).to eq(20)
    end

    context 'with region selection' do
      it 'resolves a known region' do
        conn = described_class.client(api_key: 'lk_test', region: :eu_west_1)
        expect(conn.url_prefix.to_s).to eq('https://eu-west-1.api.lakera.ai/')
      end

      it 'resolves us region' do
        conn = described_class.client(api_key: 'lk_test', region: :us)
        expect(conn.url_prefix.to_s).to eq('https://us.api.lakera.ai/')
      end

      it 'falls back to host for unknown region' do
        conn = described_class.client(api_key: 'lk_test', region: :unknown,
                                      host: 'https://custom.lakera.ai')
        expect(conn.url_prefix.to_s).to eq('https://custom.lakera.ai/')
      end
    end

    context 'with custom host' do
      it 'uses the provided host' do
        conn = described_class.client(api_key: 'lk_test', host: 'https://my-lakera.example.com')
        expect(conn.url_prefix.to_s).to eq('https://my-lakera.example.com/')
      end
    end
  end

  describe '.self_hosted_client' do
    subject(:conn) { described_class.self_hosted_client(host: 'http://lakera.internal:8000') }

    it 'returns a Faraday connection' do
      expect(conn).to be_a(Faraday::Connection)
    end

    it 'uses the provided host' do
      expect(conn.url_prefix.to_s).to eq('http://lakera.internal:8000/')
    end

    it 'does not set Authorization header' do
      expect(conn.headers['Authorization']).to be_nil
    end

    it 'sets Content-Type header' do
      expect(conn.headers['Content-Type']).to eq('application/json')
    end

    it 'sets default timeout' do
      expect(conn.options.timeout).to eq(30)
    end

    it 'accepts custom timeout values' do
      conn = described_class.self_hosted_client(host: 'http://localhost:8000', timeout: 5, open_timeout: 2)
      expect(conn.options.timeout).to eq(5)
      expect(conn.options.open_timeout).to eq(2)
    end
  end

  describe 'REGIONS' do
    it 'contains all five regional endpoints' do
      expect(described_class::REGIONS.keys).to contain_exactly(:us, :us_east_1, :us_west_2, :eu_west_1, :ap_southeast_1)
    end

    it 'is frozen' do
      expect(described_class::REGIONS).to be_frozen
    end
  end
end
