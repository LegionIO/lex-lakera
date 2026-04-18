# frozen_string_literal: true

require 'legion/extensions/lakera/helpers/client'
require 'legion/extensions/lakera/helpers/response'

module Legion
  module Extensions
    module Lakera
      module Runners
        module Policies
          extend Legion::Extensions::Lakera::Helpers::Client

          def create_policy(name:, input_detectors:, output_detectors:, api_key:, **)
            body = { name: name, input_detectors: input_detectors, output_detectors: output_detectors }
            response = client(api_key: api_key, **).post('/v2/policies', body)
            Helpers::Response.handle_response(response)
          end

          def get_policy(policy_id:, api_key:, **)
            response = client(api_key: api_key, **).get("/v2/policies/#{policy_id}")
            Helpers::Response.handle_response(response)
          end

          def update_policy(policy_id:, api_key:, name: nil, input_detectors: nil, output_detectors: nil, **)
            body = {}
            body[:name]             = name             if name
            body[:input_detectors]  = input_detectors  if input_detectors
            body[:output_detectors] = output_detectors if output_detectors

            response = client(api_key: api_key, **).put("/v2/policies/#{policy_id}", body)
            Helpers::Response.handle_response(response)
          end

          def delete_policy(policy_id:, api_key:, **)
            response = client(api_key: api_key, **).delete("/v2/policies/#{policy_id}")
            Helpers::Response.handle_response(response)
          end

          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)
        end
      end
    end
  end
end
