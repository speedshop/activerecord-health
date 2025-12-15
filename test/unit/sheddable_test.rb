# frozen_string_literal: true

require "test_helper"

class SheddableTest < ActiveRecord::Health::TestCase
  def test_sheddable_executes_block_and_returns_true_when_healthy
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.5)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    executed = false
    result = ActiveRecord::Health.sheddable(model: mock_model) { executed = true }

    assert executed
    assert result
  end

  def test_sheddable_returns_false_and_skips_block_when_overloaded
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.9)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.threshold = 0.75
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    executed = false
    result = ActiveRecord::Health.sheddable(model: mock_model) { executed = true }

    refute executed
    refute result
  end

  def test_sheddable_pct_executes_block_and_returns_true_when_below_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.4)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    executed = false
    result = ActiveRecord::Health.sheddable_pct(pct: 0.5, model: mock_model) { executed = true }

    assert executed
    assert result
  end

  def test_sheddable_pct_returns_false_and_skips_block_when_above_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.6)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    executed = false
    result = ActiveRecord::Health.sheddable_pct(pct: 0.5, model: mock_model) { executed = true }

    refute executed
    refute result
  end

  def test_sheddable_pct_executes_block_and_returns_true_when_at_threshold
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write("activerecord_health:load_pct:primary", 0.5)

    ActiveRecord::Health.configure do |config|
      config.vcpu_count = 16
      config.cache = cache
    end

    mock_model = MockModel.new("primary")
    executed = false
    result = ActiveRecord::Health.sheddable_pct(pct: 0.5, model: mock_model) { executed = true }

    assert executed
    assert result
  end
end
