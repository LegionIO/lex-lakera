# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Client do
  let(:api_key) { 'lk_test_key' }
  let(:base_url) { 'https://api.lakera.ai' }

  describe 'initialization' do
    it 'creates a SaaS client with api_key' do
      client = described_class.new(api_key: api_key)
      expect(client.config[:api_key]).to eq(api_key)
      expect(client.config[:self_hosted]).to be false
    end

    it 'creates a self-hosted client without api_key' do
      client = described_class.new(host: 'http://lakera.internal:8000', self_hosted: true)
      expect(client.config[:self_hosted]).to be true
      expect(client.config[:api_key]).to be_nil
    end

    it 'stores region in config' do
      client = described_class.new(api_key: api_key, region: :eu_west_1)
      expect(client.config[:region]).to eq(:eu_west_1)
    end

    it 'stores custom host in config' do
      client = described_class.new(api_key: api_key, host: 'https://custom.lakera.ai')
      expect(client.config[:host]).to eq('https://custom.lakera.ai')
    end

    it 'passes extra opts to config' do
      client = described_class.new(api_key: api_key, timeout: 60)
      expect(client.config[:timeout]).to eq(60)
    end
  end

  describe 'runner methods' do
    subject(:client) { described_class.new(api_key: api_key) }

    it 'responds to check' do
      expect(client).to respond_to(:check)
    end

    it 'responds to check_detailed' do
      expect(client).to respond_to(:check_detailed)
    end

    it 'responds to create_policy' do
      expect(client).to respond_to(:create_policy)
    end

    it 'responds to get_policy' do
      expect(client).to respond_to(:get_policy)
    end

    it 'responds to update_policy' do
      expect(client).to respond_to(:update_policy)
    end

    it 'responds to delete_policy' do
      expect(client).to respond_to(:delete_policy)
    end

    it 'responds to create_project' do
      expect(client).to respond_to(:create_project)
    end

    it 'responds to get_project' do
      expect(client).to respond_to(:get_project)
    end

    it 'responds to update_project' do
      expect(client).to respond_to(:update_project)
    end

    it 'responds to delete_project' do
      expect(client).to respond_to(:delete_project)
    end

    it 'responds to policy_health' do
      expect(client).to respond_to(:policy_health)
    end

    it 'responds to policy_lint' do
      expect(client).to respond_to(:policy_lint)
    end

    it 'responds to startup' do
      expect(client).to respond_to(:startup)
    end

    it 'responds to ready' do
      expect(client).to respond_to(:ready)
    end

    it 'responds to live' do
      expect(client).to respond_to(:live)
    end
  end

  describe 'SaaS integration' do
    subject(:client) { described_class.new(api_key: api_key) }

    before do
      stub_request(:post, "#{base_url}/v2/guard")
        .to_return(status: 200, body: MultiJson.dump({ 'flagged' => false, 'metadata' => { 'request_uuid' => 'abc' } }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'delegates check to Guard runner with config' do
      result = client.check(messages: [{ role: 'user', content: 'test' }], api_key: api_key)
      expect(result[:result]['flagged']).to be false
      expect(WebMock).to have_requested(:post, "#{base_url}/v2/guard")
        .with(headers: { 'Authorization' => "Bearer #{api_key}" })
    end
  end

  describe 'self-hosted integration' do
    let(:self_hosted_url) { 'http://lakera.internal:8000' }
    subject(:client) { described_class.new(host: self_hosted_url, self_hosted: true) }

    before do
      stub_request(:get, "#{self_hosted_url}/livez")
        .to_return(status: 200, body: MultiJson.dump({ 'status' => 'ok' }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'delegates live to Health runner without auth' do
      result = client.live(host: self_hosted_url)
      expect(result[:status]).to eq(200)
      expect(WebMock).to(have_requested(:get, "#{self_hosted_url}/livez")
        .with { |req| req.headers['Authorization'].nil? })
    end
  end

  describe 'region routing' do
    subject(:client) { described_class.new(api_key: api_key, region: :eu_west_1) }

    before do
      stub_request(:post, 'https://eu-west-1.api.lakera.ai/v2/guard')
        .to_return(status: 200, body: MultiJson.dump({ 'flagged' => false }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'routes requests to the regional endpoint' do
      client.check(messages: [{ role: 'user', content: 'test' }], api_key: api_key)
      expect(WebMock).to have_requested(:post, 'https://eu-west-1.api.lakera.ai/v2/guard')
    end
  end
end
