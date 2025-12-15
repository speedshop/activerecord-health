# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < ActiveRecord::Health::TestCase
  def test_configure_sets_vcpu_count
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = ActiveSupport::Cache::MemoryStore.new
    end

    assert_equal 16, ActiveRecord::Health.configuration.vcpu_count
  end

  def test_configure_sets_threshold_with_default
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = ActiveSupport::Cache::MemoryStore.new
    end

    assert_equal 0.75, ActiveRecord::Health.configuration.threshold
  end

  def test_configure_sets_custom_threshold
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.5
      config.cache = ActiveSupport::Cache::MemoryStore.new
    end

    assert_equal 0.5, ActiveRecord::Health.configuration.threshold
  end

  def test_configure_sets_cache
    cache = ActiveSupport::Cache::MemoryStore.new
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache
    end

    assert_same cache, ActiveRecord::Health.configuration.cache
  end

  def test_configure_sets_cache_ttl_with_default
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = ActiveSupport::Cache::MemoryStore.new
    end

    assert_equal 60, ActiveRecord::Health.configuration.cache_ttl
  end

  def test_configure_sets_custom_cache_ttl
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = ActiveSupport::Cache::MemoryStore.new
      config.cache_ttl = 120
    end

    assert_equal 120, ActiveRecord::Health.configuration.cache_ttl
  end

  def test_raises_without_vcpu_count
    ActiveRecord::Health.configure do |config|
      config.cache = ActiveSupport::Cache::MemoryStore.new
    end

    error = assert_raises(ActiveRecord::Health::ConfigurationError) do
      ActiveRecord::Health.configuration.validate!
    end
    assert_match(/vcpu_count/, error.message)
  end

  def test_raises_without_cache
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
    end

    error = assert_raises(ActiveRecord::Health::ConfigurationError) do
      ActiveRecord::Health.configuration.validate!
    end
    assert_match(/cache/, error.message)
  end

  def test_for_model_configures_specific_database
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = ActiveSupport::Cache::MemoryStore.new

      config.for_model(AnimalsRecord) do |db|
        db.vcpu_count = 8
        db.threshold = 0.5
      end
    end

    assert_equal 16, ActiveRecord::Health.configuration.vcpu_count
    assert_equal 8, ActiveRecord::Health.configuration.for_model(AnimalsRecord).vcpu_count
    assert_equal 0.5, ActiveRecord::Health.configuration.for_model(AnimalsRecord).threshold
  end

  def test_for_model_inherits_cache_from_default
    cache = ActiveSupport::Cache::MemoryStore.new
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache

      config.for_model(AnimalsRecord) do |db|
        db.vcpu_count = 8
      end
    end

    assert_same cache, ActiveRecord::Health.configuration.for_model(AnimalsRecord).cache
  end

  def test_for_model_inherits_threshold_from_default_when_not_specified
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = ActiveSupport::Cache::MemoryStore.new

      config.for_model(AnimalsRecord) do |db|
        db.vcpu_count = 8
      end
    end

    assert_equal 0.75, ActiveRecord::Health.configuration.for_model(AnimalsRecord).threshold
  end

  def test_max_healthy_sessions_calculated_correctly
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = ActiveSupport::Cache::MemoryStore.new
    end

    assert_equal 12, ActiveRecord::Health.configuration.max_healthy_sessions
  end
end

class AnimalsRecord
end
