# frozen_string_literal: true

require "test_helper"
require "pg"

class PostgreSQLIntegrationTest < ActiveRecord::Health::TestCase
  def setup
    super
    skip "PostgreSQL not available" unless postgresql_available?

    ActiveRecord::Base.establish_connection(
      adapter: "postgresql",
      host: ENV.fetch("POSTGRES_HOST", "localhost"),
      port: ENV.fetch("POSTGRES_PORT", 5432),
      username: ENV.fetch("POSTGRES_USER", "postgres"),
      password: ENV.fetch("POSTGRES_PASSWORD", "postgres"),
      database: ENV.fetch("POSTGRES_DB", "activerecord_health_test")
    )

    @cache = ActiveSupport::Cache::MemoryStore.new
    @baseline_sessions = count_active_sessions
    ActiveRecord::Health.configure do |config|
      config.vcpu_count = @baseline_sessions + 4
      config.threshold = 0.75
      config.cache = @cache
    end
  end

  def teardown
    @sleep_threads&.each(&:kill)
    @sleep_threads&.each(&:join)
    ActiveRecord::Base.connection_pool.disconnect!
    super
  end

  def test_load_pct_increases_with_active_sessions
    baseline_load = ActiveRecord::Health.load_pct(model: ActiveRecord::Base)
    @cache.clear

    spawn_sleeping_connections(2)
    with_load = ActiveRecord::Health.load_pct(model: ActiveRecord::Base)

    expected_increase = 2.0 / (@baseline_sessions + 4)
    assert_in_delta baseline_load + expected_increase, with_load, 0.01
  end

  def test_ok_returns_true_when_below_threshold
    @cache.clear

    assert ActiveRecord::Health.ok?(model: ActiveRecord::Base)
  end

  def test_ok_returns_false_when_above_threshold
    @cache.clear
    spawn_sleeping_connections(4)

    refute ActiveRecord::Health.ok?(model: ActiveRecord::Base)
  end

  def count_active_sessions
    ActiveRecord::Base.connection.select_value(<<~SQL).to_i
      SELECT count(*)
      FROM pg_stat_activity
      WHERE state = 'active'
        AND backend_type = 'client backend'
        AND pid != pg_backend_pid()
    SQL
  end

  private

  def postgresql_available?
    PG.connect(
      host: ENV.fetch("POSTGRES_HOST", "localhost"),
      port: ENV.fetch("POSTGRES_PORT", 5432),
      user: ENV.fetch("POSTGRES_USER", "postgres"),
      password: ENV.fetch("POSTGRES_PASSWORD", "postgres"),
      dbname: ENV.fetch("POSTGRES_DB", "activerecord_health_test")
    ).close
    true
  rescue PG::ConnectionBad
    false
  end

  def spawn_sleeping_connections(count)
    @sleep_threads = count.times.map do
      Thread.new do
        conn = PG.connect(
          host: ENV.fetch("POSTGRES_HOST", "localhost"),
          port: ENV.fetch("POSTGRES_PORT", 5432),
          user: ENV.fetch("POSTGRES_USER", "postgres"),
          password: ENV.fetch("POSTGRES_PASSWORD", "postgres"),
          dbname: ENV.fetch("POSTGRES_DB", "activerecord_health_test")
        )
        conn.exec("SELECT pg_sleep(30)")
      rescue
      ensure
        conn&.close
      end
    end

    sleep 0.5
  end
end
