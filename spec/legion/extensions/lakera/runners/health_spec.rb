# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Runners::Health do
  let(:api_key) { 'lk_test_key' }
  let(:saas_url) { 'https://api.lakera.ai' }
  let(:self_hosted_url) { 'http://lakera.internal:8000' }
  let(:errors) { Legion::Extensions::Lakera::Helpers::Errors }

  let(:health_klass) do
    Class.new do
      include Legion::Extensions::Lakera::Runners::Health

      def client(**)
        Legion::Extensions::Lakera::Helpers::Client.client(**)
      end
    end
  end

  subject(:runner) { health_klass.new }

  describe '#policy_health' do
    let(:health_response) do
      {
        'status'     => 'ok',
        'is_default' => false,
        'message'    => nil,
        'lint'       => { 'passed' => true, 'errors' => [] }
      }
    end

    context 'with SaaS (authenticated)' do
      before do
        stub_request(:post, "#{saas_url}/v2/policies/health")
          .to_return(status: 200, body: MultiJson.dump(health_response),
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns health status' do
        result = runner.policy_health(api_key: api_key)
        expect(result[:result]['status']).to eq('ok')
      end

      it 'sends Authorization header' do
        runner.policy_health(api_key: api_key)
        expect(WebMock).to have_requested(:post, "#{saas_url}/v2/policies/health")
          .with(headers: { 'Authorization' => "Bearer #{api_key}" })
      end

      it 'includes project_id when provided' do
        runner.policy_health(api_key: api_key, project_id: 'proj-123')
        expect(WebMock).to(have_requested(:post, "#{saas_url}/v2/policies/health")
          .with { |req| MultiJson.load(req.body)['project_id'] == 'proj-123' })
      end
    end

    context 'with self-hosted (unauthenticated)' do
      before do
        stub_request(:post, "#{self_hosted_url}/v2/policies/health")
          .to_return(status: 200, body: MultiJson.dump(health_response),
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns health status without auth' do
        result = runner.policy_health(host: self_hosted_url)
        expect(result[:result]['status']).to eq('ok')
      end

      it 'does not send Authorization header' do
        runner.policy_health(host: self_hosted_url)
        expect(WebMock).to(have_requested(:post, "#{self_hosted_url}/v2/policies/health")
          .with { |req| req.headers['Authorization'].nil? })
      end
    end

    context 'with error status' do
      let(:error_response) do
        {
          'status'     => 'error',
          'is_default' => true,
          'message'    => 'Policy configuration invalid',
          'lint'       => { 'passed' => false, 'errors' => [{ 'message' => 'Missing detector', 'severity' => 'error' }] }
        }
      end

      before do
        stub_request(:post, "#{saas_url}/v2/policies/health")
          .to_return(status: 200, body: MultiJson.dump(error_response),
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns error status with lint details' do
        result = runner.policy_health(api_key: api_key)
        expect(result[:result]['status']).to eq('error')
        expect(result[:result]['lint']['passed']).to be false
        expect(result[:result]['lint']['errors'].length).to eq(1)
      end
    end
  end

  describe '#policy_lint' do
    let(:lint_response) { { 'passed' => true, 'errors' => [] } }

    before do
      stub_request(:post, "#{saas_url}/v2/policies/lint")
        .to_return(status: 200, body: MultiJson.dump(lint_response),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns lint results' do
      result = runner.policy_lint(api_key: api_key)
      expect(result[:result]['passed']).to be true
    end

    context 'with lint errors' do
      let(:lint_response) do
        {
          'passed' => false,
          'errors' => [
            { 'message' => 'Invalid detector config', 'severity' => 'error' },
            { 'message' => 'Deprecated option', 'severity' => 'warning' }
          ]
        }
      end

      it 'returns errors and warnings' do
        result = runner.policy_lint(api_key: api_key)
        expect(result[:result]['passed']).to be false
        expect(result[:result]['errors'].length).to eq(2)
      end
    end
  end

  describe '#startup' do
    before do
      stub_request(:get, "#{self_hosted_url}/startupz")
        .to_return(status: 200, body: MultiJson.dump({ 'status' => 'ok' }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns startup probe status' do
      result = runner.startup(host: self_hosted_url)
      expect(result[:status]).to eq(200)
    end

    it 'does not send Authorization header' do
      runner.startup(host: self_hosted_url)
      expect(WebMock).to(have_requested(:get, "#{self_hosted_url}/startupz")
        .with { |req| req.headers['Authorization'].nil? })
    end
  end

  describe '#ready' do
    before do
      stub_request(:get, "#{self_hosted_url}/readyz")
        .to_return(status: 200, body: MultiJson.dump({ 'status' => 'ok' }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns readiness probe status' do
      result = runner.ready(host: self_hosted_url)
      expect(result[:status]).to eq(200)
    end

    it 'does not send Authorization header' do
      runner.ready(host: self_hosted_url)
      expect(WebMock).to(have_requested(:get, "#{self_hosted_url}/readyz")
        .with { |req| req.headers['Authorization'].nil? })
    end
  end

  describe '#live' do
    before do
      stub_request(:get, "#{self_hosted_url}/livez")
        .to_return(status: 200, body: MultiJson.dump({ 'status' => 'ok' }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns liveness probe status' do
      result = runner.live(host: self_hosted_url)
      expect(result[:status]).to eq(200)
    end

    it 'does not send Authorization header' do
      runner.live(host: self_hosted_url)
      expect(WebMock).to(have_requested(:get, "#{self_hosted_url}/livez")
        .with { |req| req.headers['Authorization'].nil? })
    end

    it 'raises ServerError on 503' do
      stub_request(:get, "#{self_hosted_url}/livez")
        .to_return(status: 503, body: MultiJson.dump({}),
                   headers: { 'Content-Type' => 'application/json' })

      expect { runner.live(host: self_hosted_url) }
        .to raise_error(errors::ServerError)
    end
  end
end
