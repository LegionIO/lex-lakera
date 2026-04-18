# frozen_string_literal: true

module Legion
  module Extensions
    module Lakera
      module Helpers
        module Errors
          class ApiError < StandardError
            attr_reader :status, :error_type, :body

            def initialize(message = nil, status: nil, error_type: nil, body: nil)
              super(message)
              @status     = status
              @error_type = error_type
              @body       = body
            end
          end

          class AuthenticationError  < ApiError; end
          class RateLimitError       < ApiError; end
          class InvalidRequestError  < ApiError; end
          class ServerError          < ApiError; end

          STATUS_MAP = {
            400 => InvalidRequestError,
            401 => AuthenticationError,
            429 => RateLimitError
          }.freeze

          RETRYABLE = [RateLimitError, ServerError].freeze

          module_function

          def from_response(status:, body:)
            error_hash  = body.is_a?(Hash) ? (body[:error] || body['error']) : nil
            error_type  = error_hash.is_a?(Hash) ? (error_hash[:type] || error_hash['type']) : nil
            message     = error_hash.is_a?(Hash) ? (error_hash[:message] || error_hash['message']) : nil
            message   ||= body.to_s

            klass = STATUS_MAP[status] || (status >= 500 ? ServerError : InvalidRequestError)

            klass.new(message, status: status, error_type: error_type, body: body)
          end

          def retryable?(error)
            RETRYABLE.any? { |klass| error.is_a?(klass) }
          end
        end
      end
    end
  end
end
