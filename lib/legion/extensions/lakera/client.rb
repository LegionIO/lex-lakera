# frozen_string_literal: true

require 'legion/extensions/lakera/helpers/client'
require 'legion/extensions/lakera/runners/guard'
require 'legion/extensions/lakera/runners/policies'
require 'legion/extensions/lakera/runners/projects'
require 'legion/extensions/lakera/runners/health'

module Legion
  module Extensions
    module Lakera
      class Client
        include Legion::Extensions::Lakera::Runners::Guard
        include Legion::Extensions::Lakera::Runners::Policies
        include Legion::Extensions::Lakera::Runners::Projects
        include Legion::Extensions::Lakera::Runners::Health

        attr_reader :config

        def initialize(api_key: nil, host: Helpers::Client::DEFAULT_HOST,
                       region: nil, self_hosted: false, **opts)
          @config = { api_key: api_key, host: host, region: region,
                      self_hosted: self_hosted, **opts }
        end

        private

        def client(**override_opts)
          merged = config.merge(override_opts)
          if merged[:self_hosted] && !merged[:api_key]
            Helpers::Client.self_hosted_client(**merged.except(:api_key, :self_hosted, :region))
          else
            Helpers::Client.client(**merged.except(:self_hosted))
          end
        end
      end
    end
  end
end
