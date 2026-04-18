# frozen_string_literal: true

require 'faraday'
require 'multi_json'

module Legion
  module Extensions
    module Lakera
      module Helpers
        module Client
          DEFAULT_HOST = 'https://api.lakera.ai'

          REGIONS = {
            us:             'https://us.api.lakera.ai',
            us_east_1:      'https://us-east-1.api.lakera.ai',
            us_west_2:      'https://us-west-2.api.lakera.ai',
            eu_west_1:      'https://eu-west-1.api.lakera.ai',
            ap_southeast_1: 'https://ap-southeast-1.api.lakera.ai'
          }.freeze

          module_function

          def client(api_key:, host: DEFAULT_HOST, region: nil, timeout: 30, open_timeout: 10, **_opts)
            resolved_host = region ? REGIONS.fetch(region, host) : host

            Faraday.new(url: resolved_host) do |conn|
              conn.request :json
              conn.response :json, content_type: /\bjson$/
              conn.headers['Authorization'] = "Bearer #{api_key}"
              conn.headers['Content-Type']  = 'application/json'
              conn.options.timeout      = timeout
              conn.options.open_timeout = open_timeout
            end
          end

          def self_hosted_client(host:, timeout: 30, open_timeout: 10, **_opts)
            Faraday.new(url: host) do |conn|
              conn.request :json
              conn.response :json, content_type: /\bjson$/
              conn.headers['Content-Type'] = 'application/json'
              conn.options.timeout      = timeout
              conn.options.open_timeout = open_timeout
            end
          end
        end
      end
    end
  end
end
