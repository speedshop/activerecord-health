# frozen_string_literal: true

require "test_helper"
require "rails"
require "rails/railtie"

# Reload the railtie since it's conditionally loaded
require_relative "../../lib/activerecord/health/railtie"

class RailtieTest < ActiveRecord::Health::TestCase
  def teardown
    super
    # Clean up any test Rails application
    Rails.application = nil if defined?(Rails.application) && Rails.application
  end

  def test_configuration_can_be_set_in_initializer_before_validation
    # Create a minimal Rails application
    app = Class.new(Rails::Application) do
      config.eager_load = false
      config.logger = Logger.new(nil)

      # Simulate a user's config/initializers/activerecord_health.rb
      # This initializer should run BEFORE validation
      initializer "test.configure_activerecord_health", before: :load_config_initializers do
        ActiveRecord::Health.configure do |config|
          config.vcpu_count = 4
          config.cache = ActiveSupport::Cache::MemoryStore.new
        end
      end
    end

    # This should NOT raise ConfigurationError
    # With the bug: initializer runs before config/initializers, so validation fails
    # With the fix: after_initialize runs after all initializers, so validation passes
    app.initialize!
    assert true # If we got here, no exception was raised
  end
end
