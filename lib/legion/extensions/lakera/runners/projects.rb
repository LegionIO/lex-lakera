# frozen_string_literal: true

require 'legion/extensions/lakera/helpers/client'
require 'legion/extensions/lakera/helpers/response'

module Legion
  module Extensions
    module Lakera
      module Runners
        module Projects
          extend Legion::Extensions::Lakera::Helpers::Client

          def create_project(name:, api_key:, policy_id: nil, metadata: {}, **)
            body = { name: name }
            body[:policy_id] = policy_id unless policy_id.nil?
            body[:metadata]  = metadata  unless metadata.empty?

            response = client(api_key: api_key, **).post('/v2/projects', body)
            Helpers::Response.handle_response(response)
          end

          def get_project(project_id:, api_key:, **)
            response = client(api_key: api_key, **).get("/v2/projects/#{project_id}")
            Helpers::Response.handle_response(response)
          end

          def update_project(project_id:, api_key:, name: nil, policy_id: nil, metadata: {}, **)
            body = {}
            body[:name]      = name      if name
            body[:policy_id] = policy_id if policy_id
            body[:metadata]  = metadata  unless metadata.empty?

            response = client(api_key: api_key, **).put("/v2/projects/#{project_id}", body)
            Helpers::Response.handle_response(response)
          end

          def delete_project(project_id:, api_key:, **)
            response = client(api_key: api_key, **).delete("/v2/projects/#{project_id}")
            Helpers::Response.handle_response(response)
          end

          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)
        end
      end
    end
  end
end
