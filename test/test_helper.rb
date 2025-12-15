# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_record"
require "active_support"
require "active_support/core_ext/string"
require "active_support/cache"
require "activerecord/health"

require "minitest/autorun"
require "minitest/reporters"

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new

if ENV["FAIL_ON_SKIP"]
  module Minitest
    class << self
      alias_method :original_run, :run

      def run(args = [])
        result = original_run(args)
        reporter = Minitest::Reporters.reporters.first
        if reporter && reporter.skips > 0
          warn "\nCI failed: #{reporter.skips} tests were skipped"
          exit 1
        end
        result
      end
    end
  end
end

class ActiveRecord::Health::TestCase < Minitest::Test
  def setup
    ActiveRecord::Health.reset_configuration!
  end

  def teardown
    ActiveRecord::Health.reset_configuration!
  end
end

class FailingCache
  def read(key)
    raise "Cache connection failed"
  end

  def write(key, value, options = {})
    raise "Cache connection failed"
  end
end
