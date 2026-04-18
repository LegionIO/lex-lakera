# frozen_string_literal: true

require 'legion/extensions/lakera/helpers/errors'

module Legion
  module Extensions
    module Lakera
      module Helpers
        module Response
          module_function

          def handle_response(response)
            unless response.status >= 200 && response.status < 300
              raise Errors.from_response(status: response.status, body: response.body)
            end

            { result: response.body, status: response.status }
          end
        end
      end
    end
  end
end
