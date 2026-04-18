# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Runners::Policies do
  let(:api_key) { 'lk_test_key' }
  let(:base_url) { 'https://api.lakera.ai' }
  let(:errors) { Legion::Extensions::Lakera::Helpers::Errors }

  let(:policies_klass) do
    Class.new do
      include Legion::Extensions::Lakera::Runners::Policies

      def client(**)
        Legion::Extensions::Lakera::Helpers::Client.client(**)
      end
    end
  end

  subject(:runner) { policies_klass.new }

  describe '#create_policy' do
    let(:policy_response) { { 'id' => 'pol_123', 'name' => 'Strict Policy' } }
    let(:input_detectors) { [{ type: 'prompt_attack', sensitivity: 'L4' }] }
    let(:output_detectors) { [{ type: 'pii', sensitivity: 'L2' }] }

    before do
      stub_request(:post, "#{base_url}/v2/policies")
        .to_return(status: 201, body: MultiJson.dump(policy_response),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates a policy and returns the result' do
      result = runner.create_policy(name: 'Strict Policy', input_detectors: input_detectors,
                                    output_detectors: output_detectors, api_key: api_key)
      expect(result[:status]).to eq(201)
      expect(result[:result]['id']).to eq('pol_123')
    end

    it 'sends detector configuration in request body' do
      runner.create_policy(name: 'Test', input_detectors: input_detectors,
                           output_detectors: output_detectors, api_key: api_key)
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/policies")
        .with { |req| MultiJson.load(req.body)['input_detectors'].is_a?(Array) })
    end
  end

  describe '#get_policy' do
    let(:policy_response) { { 'id' => 'pol_123', 'name' => 'My Policy' } }

    before do
      stub_request(:get, "#{base_url}/v2/policies/pol_123")
        .to_return(status: 200, body: MultiJson.dump(policy_response),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'retrieves a policy by id' do
      result = runner.get_policy(policy_id: 'pol_123', api_key: api_key)
      expect(result[:result]['name']).to eq('My Policy')
    end

    it 'raises on 404' do
      stub_request(:get, "#{base_url}/v2/policies/pol_missing")
        .to_return(status: 404, body: MultiJson.dump({ error: { message: 'Not found' } }),
                   headers: { 'Content-Type' => 'application/json' })

      expect { runner.get_policy(policy_id: 'pol_missing', api_key: api_key) }
        .to raise_error(errors::InvalidRequestError)
    end
  end

  describe '#update_policy' do
    before do
      stub_request(:put, "#{base_url}/v2/policies/pol_123")
        .to_return(status: 200, body: MultiJson.dump({ 'id' => 'pol_123', 'name' => 'Updated' }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'updates a policy' do
      result = runner.update_policy(policy_id: 'pol_123', api_key: api_key, name: 'Updated')
      expect(result[:result]['name']).to eq('Updated')
    end

    it 'sends only provided fields' do
      runner.update_policy(policy_id: 'pol_123', api_key: api_key, name: 'New Name')
      expect(WebMock).to(have_requested(:put, "#{base_url}/v2/policies/pol_123")
        .with do |req|
          body = MultiJson.load(req.body)
          body.key?('name') && !body.key?('input_detectors')
        end)
    end

    it 'raises AuthenticationError on 401' do
      stub_request(:put, "#{base_url}/v2/policies/pol_123")
        .to_return(status: 401, body: MultiJson.dump({}),
                   headers: { 'Content-Type' => 'application/json' })

      expect { runner.update_policy(policy_id: 'pol_123', api_key: 'bad') }
        .to raise_error(errors::AuthenticationError)
    end
  end

  describe '#delete_policy' do
    before do
      stub_request(:delete, "#{base_url}/v2/policies/pol_123")
        .to_return(status: 200, body: MultiJson.dump({ 'deleted' => true }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'deletes a policy' do
      result = runner.delete_policy(policy_id: 'pol_123', api_key: api_key)
      expect(result[:status]).to eq(200)
    end

    it 'raises on 401' do
      stub_request(:delete, "#{base_url}/v2/policies/pol_456")
        .to_return(status: 401, body: MultiJson.dump({}),
                   headers: { 'Content-Type' => 'application/json' })

      expect { runner.delete_policy(policy_id: 'pol_456', api_key: 'bad') }
        .to raise_error(errors::AuthenticationError)
    end
  end
end
