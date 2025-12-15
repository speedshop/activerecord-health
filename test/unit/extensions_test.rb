# frozen_string_literal: true

require "test_helper"
require "activerecord/health/extensions"

class ConnectionExtensionTest < ActiveRecord::Health::TestCase
  def test_healthy_returns_true_when_below_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.5)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    connection = MockConnectionWithExtension.new("primary")
    assert connection.healthy?
  end

  def test_healthy_returns_false_when_above_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.9)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    connection = MockConnectionWithExtension.new("primary")
    refute connection.healthy?
  end

  def test_load_pct_returns_cached_value
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.625)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache
    end

    connection = MockConnectionWithExtension.new("primary")
    assert_equal 0.625, connection.load_pct
  end
end

class ModelExtensionTest < ActiveRecord::Health::TestCase
  def test_database_healthy_returns_true_when_below_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.5)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    assert MockModelWithExtension.database_healthy?
  end

  def test_database_healthy_returns_false_when_above_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.9)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    refute MockModelWithExtension.database_healthy?
  end
end

MockExtensionDbConfig = Struct.new(:name)

class MockConnectionWithExtension
  include ActiveRecord::Health::ConnectionExtension

  def initialize(db_config_name)
    @db_config_name = db_config_name
  end

  def adapter_name
    "PostgreSQL"
  end

  def select_value(query)
    0
  end

  def pool
    self
  end

  def db_config
    MockExtensionDbConfig.new(@db_config_name)
  end
end

class MockModelWithExtension
  extend ActiveRecord::Health::ModelExtension

  def self.connection_db_config
    MockExtensionDbConfig.new("primary")
  end

  def self.connection
    MockConnectionWithExtension.new("primary")
  end
end
