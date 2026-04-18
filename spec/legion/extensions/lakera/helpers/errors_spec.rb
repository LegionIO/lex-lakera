# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Helpers::Errors do
  describe '.from_response' do
    it 'returns AuthenticationError for 401' do
      error = described_class.from_response(status: 401, body: {})
      expect(error).to be_a(described_class::AuthenticationError)
      expect(error.status).to eq(401)
    end

    it 'returns RateLimitError for 429' do
      error = described_class.from_response(status: 429, body: {})
      expect(error).to be_a(described_class::RateLimitError)
      expect(error.status).to eq(429)
    end

    it 'returns InvalidRequestError for 400' do
      error = described_class.from_response(status: 400, body: {})
      expect(error).to be_a(described_class::InvalidRequestError)
      expect(error.status).to eq(400)
    end

    it 'returns ServerError for 500' do
      error = described_class.from_response(status: 500, body: {})
      expect(error).to be_a(described_class::ServerError)
      expect(error.status).to eq(500)
    end

    it 'returns ServerError for 503' do
      error = described_class.from_response(status: 503, body: {})
      expect(error).to be_a(described_class::ServerError)
    end

    it 'returns InvalidRequestError for unknown 4xx' do
      error = described_class.from_response(status: 422, body: {})
      expect(error).to be_a(described_class::InvalidRequestError)
    end

    it 'extracts message from error hash with symbol keys' do
      body = { error: { type: 'authentication_error', message: 'Invalid API key' } }
      error = described_class.from_response(status: 401, body: body)
      expect(error.message).to eq('Invalid API key')
      expect(error.error_type).to eq('authentication_error')
    end

    it 'extracts message from error hash with string keys' do
      body = { 'error' => { 'type' => 'rate_limit_error', 'message' => 'Too many requests' } }
      error = described_class.from_response(status: 429, body: body)
      expect(error.message).to eq('Too many requests')
    end

    it 'falls back to body.to_s when no error hash' do
      error = described_class.from_response(status: 400, body: 'raw error text')
      expect(error.message).to eq('raw error text')
    end

    it 'stores the full body on the error' do
      body = { error: { message: 'fail' } }
      error = described_class.from_response(status: 400, body: body)
      expect(error.body).to eq(body)
    end
  end

  describe '.retryable?' do
    it 'returns true for RateLimitError' do
      error = described_class::RateLimitError.new('rate limited')
      expect(described_class.retryable?(error)).to be true
    end

    it 'returns true for ServerError' do
      error = described_class::ServerError.new('server error')
      expect(described_class.retryable?(error)).to be true
    end

    it 'returns false for AuthenticationError' do
      error = described_class::AuthenticationError.new('unauthorized')
      expect(described_class.retryable?(error)).to be false
    end

    it 'returns false for InvalidRequestError' do
      error = described_class::InvalidRequestError.new('bad request')
      expect(described_class.retryable?(error)).to be false
    end
  end

  describe 'error hierarchy' do
    it 'all errors inherit from ApiError' do
      [
        described_class::AuthenticationError,
        described_class::RateLimitError,
        described_class::InvalidRequestError,
        described_class::ServerError
      ].each do |klass|
        expect(klass.ancestors).to include(described_class::ApiError)
      end
    end

    it 'ApiError inherits from StandardError' do
      expect(described_class::ApiError.ancestors).to include(StandardError)
    end
  end
end
