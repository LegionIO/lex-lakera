# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera::Runners::Projects do
  let(:api_key) { 'lk_test_key' }
  let(:base_url) { 'https://api.lakera.ai' }
  let(:errors) { Legion::Extensions::Lakera::Helpers::Errors }

  let(:projects_klass) do
    Class.new do
      include Legion::Extensions::Lakera::Runners::Projects

      def client(**)
        Legion::Extensions::Lakera::Helpers::Client.client(**)
      end
    end
  end

  subject(:runner) { projects_klass.new }

  describe '#create_project' do
    let(:project_response) { { 'id' => 'project-abc', 'name' => 'Production App' } }

    before do
      stub_request(:post, "#{base_url}/v2/projects")
        .to_return(status: 201, body: MultiJson.dump(project_response),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates a project' do
      result = runner.create_project(name: 'Production App', api_key: api_key)
      expect(result[:status]).to eq(201)
      expect(result[:result]['id']).to eq('project-abc')
    end

    it 'includes policy_id when provided' do
      runner.create_project(name: 'Test', api_key: api_key, policy_id: 'pol_123')
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/projects")
        .with { |req| MultiJson.load(req.body)['policy_id'] == 'pol_123' })
    end

    it 'omits policy_id when nil' do
      runner.create_project(name: 'Test', api_key: api_key)
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/projects")
        .with { |req| !MultiJson.load(req.body).key?('policy_id') })
    end

    it 'includes metadata when provided' do
      runner.create_project(name: 'Test', api_key: api_key, metadata: { application: 'chatbot' })
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/projects")
        .with { |req| MultiJson.load(req.body)['metadata'] == { 'application' => 'chatbot' } })
    end

    it 'omits metadata when empty' do
      runner.create_project(name: 'Test', api_key: api_key, metadata: {})
      expect(WebMock).to(have_requested(:post, "#{base_url}/v2/projects")
        .with { |req| !MultiJson.load(req.body).key?('metadata') })
    end
  end

  describe '#get_project' do
    before do
      stub_request(:get, "#{base_url}/v2/projects/project-abc")
        .to_return(status: 200, body: MultiJson.dump({ 'id' => 'project-abc', 'name' => 'My App' }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'retrieves a project' do
      result = runner.get_project(project_id: 'project-abc', api_key: api_key)
      expect(result[:result]['name']).to eq('My App')
    end

    it 'raises on 404' do
      stub_request(:get, "#{base_url}/v2/projects/missing")
        .to_return(status: 404, body: MultiJson.dump({}),
                   headers: { 'Content-Type' => 'application/json' })

      expect { runner.get_project(project_id: 'missing', api_key: api_key) }
        .to raise_error(errors::InvalidRequestError)
    end
  end

  describe '#update_project' do
    before do
      stub_request(:put, "#{base_url}/v2/projects/project-abc")
        .to_return(status: 200, body: MultiJson.dump({ 'id' => 'project-abc', 'name' => 'Updated' }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'updates a project' do
      result = runner.update_project(project_id: 'project-abc', api_key: api_key, name: 'Updated')
      expect(result[:result]['name']).to eq('Updated')
    end

    it 'sends only provided fields' do
      runner.update_project(project_id: 'project-abc', api_key: api_key, name: 'New')
      expect(WebMock).to(have_requested(:put, "#{base_url}/v2/projects/project-abc")
        .with do |req|
          body = MultiJson.load(req.body)
          body.key?('name') && !body.key?('policy_id')
        end)
    end
  end

  describe '#delete_project' do
    before do
      stub_request(:delete, "#{base_url}/v2/projects/project-abc")
        .to_return(status: 200, body: MultiJson.dump({ 'deleted' => true }),
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'deletes a project' do
      result = runner.delete_project(project_id: 'project-abc', api_key: api_key)
      expect(result[:status]).to eq(200)
    end

    it 'raises on 401' do
      stub_request(:delete, "#{base_url}/v2/projects/project-abc")
        .to_return(status: 401, body: MultiJson.dump({}),
                   headers: { 'Content-Type' => 'application/json' })

      expect { runner.delete_project(project_id: 'project-abc', api_key: 'bad') }
        .to raise_error(errors::AuthenticationError)
    end
  end
end
