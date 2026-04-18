# frozen_string_literal: true

require 'legion/extensions/lakera/version'
require 'legion/extensions/lakera/helpers/client'
require 'legion/extensions/lakera/helpers/errors'
require 'legion/extensions/lakera/helpers/retry'
require 'legion/extensions/lakera/helpers/response'
require 'legion/extensions/lakera/runners/guard'
require 'legion/extensions/lakera/runners/policies'
require 'legion/extensions/lakera/runners/projects'
require 'legion/extensions/lakera/runners/health'
require 'legion/extensions/lakera/client'
require 'legion/extensions/lakera/identity'

module Legion
  module Extensions
    module Lakera
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core, false
    end
  end
end
