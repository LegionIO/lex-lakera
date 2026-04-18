# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Runners::Guard do
  let(:api_key) { 'lk_test_key' }
  let(:base_url) { 'https://api.lakera.ai' }
  let(:messages) { [{ role: 'user', content: 'Hello world' }] }

  let(:guard_klass) do
    Class.new do
      include Legion::Extensions::Lakera::Runners::Guard

      def client(**)
        Legion::Extensions::Lakera::Helpers::Client.client(**)
      end
    end
  end

  subject(:runner) { guard_klass.new }

  describe '#check' do
    let(:guard_response) do
      {
        'flagged'  => false,
        'metadata' => { 'request_uuid' => 'uuid-123' }
      }
    end

    before do
      stub_request(:post, "#{base_url}/v2/guard")
        .to_return(status: 200, body: MultiJson.dump(guard_response),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a result with flagged status' do
      result = runner.check(messages: messages, api_key: api_key)
      expect(result[:status]).to eq(200)
      expect(result[:result]['flagged']).to be false
    end

    it 'sends messages in the request body' do
      runner.check(messages: messages, api_key: api_key)
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
        .with { |req| MultiJson.load(req.body)['messages'] == [{ 'role' => 'user', 'content' => 'Hello world' }] })
    end

    it 'includes breakdown by default' do
      runner.check(messages: messages, api_key: api_key)
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
        .with { |req| MultiJson.load(req.body)['breakdown'] == true })
    end

    it 'excludes payload by default' do
      runner.check(messages: messages, api_key: api_key)
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
        .with { |req| MultiJson.load(req.body)['payload'] == false })
    end

    it 'includes project_id when provided' do
      runner.check(messages: messages, api_key: api_key, project_id: 'proj-123')
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
        .with { |req| MultiJson.load(req.body)['project_id'] == 'proj-123' })
    end

    it 'includes metadata when provided' do
      meta = { user_id: 'u-1', session_id: 's-1' }
      runner.check(messages: messages, api_key: api_key, metadata: meta)
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
        .with { |req| MultiJson.load(req.body)['metadata'] == { 'user_id' => 'u-1', 'session_id' => 's-1' } })
    end

    it 'omits metadata when empty' do
      runner.check(messages: messages, api_key: api_key, metadata: {})
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
        .with { |req| !MultiJson.load(req.body).key?('metadata') })
    end

    it 'includes dev_info when true' do
      runner.check(messages: messages, api_key: api_key, dev_info: true)
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
        .with { |req| MultiJson.load(req.body)['dev_info'] == true })
    end

    context 'with flagged content' do
      let(:guard_response) do
        {
          'flagged'   => true,
          'breakdown' => [
            { 'detector_type' => 'prompt_attack', 'detected' => true, 'detector_id' => 'det-1', 'message_id' => 0 }
          ],
          'payload'   => [
            { 'start' => 0, 'end' => 5, 'text' => 'Hello', 'detector_type' => 'pii', 'labels' => ['name'],
              'message_id' => 0 }
          ],
          'metadata'  => { 'request_uuid' => 'uuid-456' }
        }
      end

      it 'returns flagged true with breakdown and payload' do
        result = runner.check(messages: messages, api_key: api_key, payload: true)
        expect(result[:result]['flagged']).to be true
        expect(result[:result]['breakdown']).to be_an(Array)
        expect(result[:result]['payload']).to be_an(Array)
      end
    end

    context 'with multi-message conversation' do
      let(:multi_messages) do
        [
          { role: 'system', content: 'You are a helpful assistant' },
          { role: 'user', content: 'What is 2+2?' },
          { role: 'assistant', content: '4' },
          { role: 'user', content: 'Thanks' }
        ]
      end

      it 'sends all messages' do
        runner.check(messages: multi_messages, api_key: api_key)
        expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
          .with { |req| MultiJson.load(req.body)['messages'].length == 4 })
      end
    end

    context 'with ContentPart array format' do
      let(:content_part_messages) do
        [{ role: 'user', content: [{ type: 'text', text: 'Hello' }] }]
      end

      it 'sends content parts as-is' do
        runner.check(messages: content_part_messages, api_key: api_key)
        expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard")
          .with { |req| MultiJson.load(req.body)['messages'][0]['content'].is_a?(Array) })
      end
    end

    context 'with error responses' do
      it 'raises AuthenticationError on 401' do
        stub_request(:post, "#{base_url}/v2/guard")
          .to_return(status: 401, body: MultiJson.dump({ error: { message: 'Unauthorized' } }),
                     headers: { 'Content-Type' => 'application/json' })

        expect { runner.check(messages: messages, api_key: 'bad_key') }
          .to raise_error(Legion::Extensions::Lakera::Helpers::Errors::AuthenticationError)
      end

      it 'raises RateLimitError on 429' do
        stub_request(:post, "#{base_url}/v2/guard")
          .to_return(status: 429, body: MultiJson.dump({}),
                     headers: { 'Content-Type' => 'application/json' })

        expect { runner.check(messages: messages, api_key: api_key) }
          .to raise_error(Legion::Extensions::Lakera::Helpers::Errors::RateLimitError)
      end

      it 'raises ServerError on 500' do
        stub_request(:post, "#{base_url}/v2/guard")
          .to_return(status: 500, body: MultiJson.dump({}),
                     headers: { 'Content-Type' => 'application/json' })

        expect { runner.check(messages: messages, api_key: api_key) }
          .to raise_error(Legion::Extensions::Lakera::Helpers::Errors::ServerError)
      end
    end
  end

  describe '#check_detailed' do
    let(:detailed_response) do
      {
        'results' => [
          { 'detector_type' => 'prompt_attack', 'result' => 'l1_confident', 'custom_matched' => false,
            'message_id' => 0 },
          { 'detector_type' => 'pii', 'result' => 'l5_unlikely', 'custom_matched' => false, 'message_id' => 0 },
          { 'detector_type' => 'moderated_content', 'result' => 'no_level', 'custom_matched' => false,
            'message_id' => 0 }
        ]
      }
    end

    before do
      stub_request(:post, "#{base_url}/v2/guard/results")
        .to_return(status: 200, body: MultiJson.dump(detailed_response),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns detailed results' do
      result = runner.check_detailed(messages: messages, api_key: api_key)
      expect(result[:status]).to eq(200)
      expect(result[:result]['results']).to be_an(Array)
      expect(result[:result]['results'].length).to eq(3)
    end

    it 'includes confidence levels' do
      result = runner.check_detailed(messages: messages, api_key: api_key)
      levels = result[:result]['results'].map { |r| r['result'] }
      expect(levels).to include('l1_confident', 'l5_unlikely', 'no_level')
    end

    it 'includes project_id when provided' do
      runner.check_detailed(messages: messages, api_key: api_key, project_id: 'proj-abc')
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/guard/results")
        .with { |req| MultiJson.load(req.body)['project_id'] == 'proj-abc' })
    end

    it 'raises AuthenticationError on 401' do
      stub_request(:post, "#{base_url}/v2/guard/results")
        .to_return(status: 401, body: MultiJson.dump({}),
                   headers: { 'Content-Type' => 'application/json' })

      expect { runner.check_detailed(messages: messages, api_key: 'bad') }
        .to raise_error(Legion::Extensions::Lakera::Helpers::Errors::AuthenticationError)
    end
  end
end
