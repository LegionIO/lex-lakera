# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Helpers::Response do
  let(:errors) { Legion::Extensions::Lakera::Helpers::Errors }

  describe '.handle_response' do
    it 'returns result hash for 200 response' do
      response = instance_double(Faraday::Response, status: 200, body: { 'flagged' => false })
      result = described_class.handle_response(response)
      expect(result).to eq({ result: { 'flagged' => false }, status: 200 })
    end

    it 'returns result hash for 201 response' do
      response = instance_double(Faraday::Response, status: 201, body: { 'id' => 'pol_123' })
      result = described_class.handle_response(response)
      expect(result[:status]).to eq(201)
    end

    it 'raises AuthenticationError for 401' do
      response = instance_double(Faraday::Response, status: 401, body: { 'error' => { 'message' => 'Unauthorized' } })
      expect { described_class.handle_response(response) }.to raise_error(errors::AuthenticationError)
    end

    it 'raises RateLimitError for 429' do
      response = instance_double(Faraday::Response, status: 429, body: {})
      expect { described_class.handle_response(response) }.to raise_error(errors::RateLimitError)
    end

    it 'raises InvalidRequestError for 400' do
      response = instance_double(Faraday::Response, status: 400, body: {})
      expect { described_class.handle_response(response) }.to raise_error(errors::InvalidRequestError)
    end

    it 'raises ServerError for 500' do
      response = instance_double(Faraday::Response, status: 500, body: {})
      expect { described_class.handle_response(response) }.to raise_error(errors::ServerError)
    end

    it 'preserves the full response body in result' do
      body = { 'flagged' => true, 'breakdown' => [{ 'detected' => true }], 'metadata' => { 'request_uuid' => 'abc' } }
      response = instance_double(Faraday::Response, status: 200, body: body)
      result = described_class.handle_response(response)
      expect(result[:result]).to eq(body)
    end
  end
end
