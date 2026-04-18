# frozen_string_literal: true

require 'legion/extensions/lakera/helpers/client'
require 'legion/extensions/lakera/helpers/response'

module Legion
  module Extensions
    module Lakera
      module Runners
        module Health
          extend Legion::Extensions::Lakera::Helpers::Client

          def policy_health(api_key: nil, project_id: nil, host: nil, **)
            body = {}
            body[:project_id] = project_id if project_id

            conn = resolve_health_client(api_key: api_key, host: host, **)
            response = conn.post('/v2/policies/health', body)
            Helpers::Response.handle_response(response)
          end

          def policy_lint(api_key: nil, host: nil, **)
            conn = resolve_health_client(api_key: api_key, host: host, **)
            response = conn.post('/v2/policies/lint')
            Helpers::Response.handle_response(response)
          end

          def startup(host:, **)
            conn = Helpers::Client.self_hosted_client(host: host, **)
            response = conn.get('/startupz')
            Helpers::Response.handle_response(response)
          end

          def ready(host:, **)
            conn = Helpers::Client.self_hosted_client(host: host, **)
            response = conn.get('/readyz')
            Helpers::Response.handle_response(response)
          end

          def live(host:, **)
            conn = Helpers::Client.self_hosted_client(host: host, **)
            response = conn.get('/livez')
            Helpers::Response.handle_response(response)
          end

          private

          def resolve_health_client(api_key:, host:, **)
            if api_key
              Helpers::Client.client(api_key: api_key, host: host || Helpers::Client::DEFAULT_HOST, **)
            else
              Helpers::Client.self_hosted_client(host: host || Helpers::Client::DEFAULT_HOST, **)
            end
          end

          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)
        end
      end
    end
  end
end
