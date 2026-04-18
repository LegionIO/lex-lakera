# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Helpers::Retry do
  let(:errors) { Legion::Extensions::Lakera::Helpers::Errors }

  describe '.with_retry' do
    it 'returns the block result on success' do
      result = described_class.with_retry { 42 }
      expect(result).to eq(42)
    end

    it 'retries on retryable errors and succeeds' do
      attempts = 0
      result = described_class.with_retry(base_delay: 0) do
        attempts += 1
        raise errors::RateLimitError.new('rate limited', status: 429) if attempts < 2

        'success'
      end
      expect(result).to eq('success')
      expect(attempts).to eq(2)
    end

    it 'raises after max_attempts exhausted' do
      attempts = 0
      expect do
        described_class.with_retry(max_attempts: 2, base_delay: 0) do
          attempts += 1
          raise errors::ServerError.new('fail', status: 500)
        end
      end.to raise_error(errors::ServerError)
      expect(attempts).to eq(2)
    end

    it 'raises immediately for non-retryable errors' do
      attempts = 0
      expect do
        described_class.with_retry(base_delay: 0) do
          attempts += 1
          raise errors::AuthenticationError.new('unauthorized', status: 401)
        end
      end.to raise_error(errors::AuthenticationError)
      expect(attempts).to eq(1)
    end

    it 'raises immediately for InvalidRequestError' do
      attempts = 0
      expect do
        described_class.with_retry(base_delay: 0) do
          attempts += 1
          raise errors::InvalidRequestError.new('bad', status: 400)
        end
      end.to raise_error(errors::InvalidRequestError)
      expect(attempts).to eq(1)
    end
  end

  describe '.backoff_seconds' do
    it 'returns base_delay for attempt 0' do
      expect(described_class.backoff_seconds(attempt: 0)).to eq(1.0)
    end

    it 'doubles for each attempt' do
      expect(described_class.backoff_seconds(attempt: 1)).to eq(2.0)
      expect(described_class.backoff_seconds(attempt: 2)).to eq(4.0)
      expect(described_class.backoff_seconds(attempt: 3)).to eq(8.0)
    end

    it 'caps at max_delay' do
      expect(described_class.backoff_seconds(attempt: 10, max_delay: 60.0)).to eq(60.0)
    end

    it 'respects custom base_delay' do
      expect(described_class.backoff_seconds(attempt: 0, base_delay: 0.5)).to eq(0.5)
    end
  end
end
