# frozen_string_literal: true

require "test_helper"

class HealthTest < ActiveRecord::Health::TestCase
  def test_ok_returns_true_when_load_below_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.5)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    assert ActiveRecord::Health.ok?(model: mock_model)
  end

  def test_ok_returns_false_when_load_above_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.9)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    refute ActiveRecord::Health.ok?(model: mock_model)
  end

  def test_ok_returns_true_when_load_equals_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.75)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    assert ActiveRecord::Health.ok?(model: mock_model)
  end

  def test_ok_returns_true_when_cache_fails
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = FailingCache.new
    end

    mock_model = MockModel.new("primary")
    assert ActiveRecord::Health.ok?(model: mock_model)
  end

  def test_load_pct_returns_cached_value
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.625)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    assert_equal 0.625, ActiveRecord::Health.load_pct(model: mock_model)
  end

  def test_load_pct_returns_zero_when_cache_fails
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = FailingCache.new
    end

    mock_model = MockModel.new("primary")
    assert_equal 0.0, ActiveRecord::Health.load_pct(model: mock_model)
  end

  def test_load_pct_queries_database_when_not_cached
    cache = ActiveSupport::Cache::MemoryStore.new

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache
    end

    connection = MockConnection.new(active_session_count: 8)
    mock_model = MockModel.new("primary", connection)

    assert_equal 0.5, ActiveRecord::Health.load_pct(model: mock_model)
    assert_equal 0.5, cache.read("activerecord_health:load_pct:primary")
  end

  def test_load_pct_returns_1_0_when_database_query_fails
    cache = ActiveSupport::Cache::MemoryStore.new

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache
    end

    connection = MockConnection.new(should_fail: true)
    mock_model = MockModel.new("primary", connection)

    assert_equal 1.0, ActiveRecord::Health.load_pct(model: mock_model)
  end

  def test_ok_returns_false_when_database_query_fails
    cache = ActiveSupport::Cache::MemoryStore.new

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    connection = MockConnection.new(should_fail: true)
    mock_model = MockModel.new("primary", connection)

    refute ActiveRecord::Health.ok?(model: mock_model)
  end

  def test_uses_per_model_configuration
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:animals", 0.6)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache

      config.for_model(AnimalsRecord) do |db|
        db.vcpu_count = 8
        db.threshold = 0.5
      end
    end

    mock_model = MockModel.new("animals")
    mock_model.define_singleton_method(:class) { AnimalsRecord }

    refute ActiveRecord::Health.ok?(model: mock_model)
  end
end

MockDbConfig = Struct.new(:name)

class MockModel
  attr_reader :connection

  def initialize(db_config_name, connection = nil)
    @db_config_name = db_config_name
    @connection = connection || MockConnection.new
  end

  def connection_db_config
    MockDbConfig.new(@db_config_name)
  end

  def class
    ActiveRecord::Base
  end
end

class MockConnection
  def initialize(active_session_count: 0, should_fail: false)
    @active_session_count = active_session_count
    @should_fail = should_fail
  end

  def adapter_name
    "PostgreSQL"
  end

  def select_value(query)
    raise "Connection failed" if @should_fail
    @active_session_count
  end

  def execute(query)
    raise "Connection failed" if @should_fail
  end

  def transaction
    raise "Connection failed" if @should_fail
    yield
  end
end
