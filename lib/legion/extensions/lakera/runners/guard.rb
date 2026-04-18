# frozen_string_literal: true

require 'legion/extensions/lakera/helpers/client'
require 'legion/extensions/lakera/helpers/response'

module Legion
  module Extensions
    module Lakera
      module Runners
        module Guard
          extend Legion::Extensions::Lakera::Helpers::Client

          def check(messages:, api_key:, project_id: nil, breakdown: true,
                    payload: false, metadata: {}, dev_info: false, **)
            body = { messages: messages }
            body[:project_id] = project_id if project_id
            body[:breakdown]  = breakdown
            body[:payload]    = payload
            body[:metadata]   = metadata unless metadata.empty?
            body[:dev_info]   = dev_info if dev_info

            response = client(api_key: api_key, **).post('/v2/guard', body)
            Helpers::Response.handle_response(response)
          end

          def check_detailed(messages:, api_key:, project_id: nil, metadata: {}, dev_info: false, **)
            body = { messages: messages }
            body[:project_id] = project_id if project_id
            body[:metadata]   = metadata unless metadata.empty?
            body[:dev_info]   = dev_info if dev_info

            response = client(api_key: api_key, **).post('/v2/guard/results', body)
            Helpers::Response.handle_response(response)
          end

          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)
        end
      end
    end
  end
end
