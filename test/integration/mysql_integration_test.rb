# frozen_string_literal: true

require "test_helper"
require "mysql2"

class MySQLIntegrationTest < ActiveRecord::Health::TestCase
  def setup
    super
    skip "MySQL not available" unless mysql_available?

    ActiveRecord::Base.establish_connection(
      adapter: "mysql2",
      host: ENV.fetch("MYSQL_HOST", "127.0.0.1"),
      port: ENV.fetch("MYSQL_PORT", 3306).to_i,
      username: ENV.fetch("MYSQL_USER", "root"),
      password: ENV.fetch("MYSQL_PASSWORD", "root"),
      database: ENV.fetch("MYSQL_DB", "activerecord_health_test")
    )

    @cache = MockCache.new
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
    version = ActiveRecord::Base.connection.select_value("SELECT VERSION()")
    adapter = ActiveRecord::Health::Adapters::MySQLAdapter.new(version)
    ActiveRecord::Base.connection.select_value(adapter.active_session_count_query).to_i
  end

  private

  def mysql_available?
    Mysql2::Client.new(mysql_config).close
    true
  rescue Mysql2::Error => e
    warn "MySQL connection failed: #{e.message}"
    false
  end

  def spawn_sleeping_connections(count)
    @sleep_threads = count.times.map do
      Thread.new do
        client = Mysql2::Client.new(mysql_config)
        client.query("SELECT SLEEP(30)")
      rescue
      ensure
        client&.close
      end
    end

    sleep 0.5
  end

  def mysql_config
    {
      host: ENV.fetch("MYSQL_HOST", "127.0.0.1"),
      port: ENV.fetch("MYSQL_PORT", 3306).to_i,
      username: ENV.fetch("MYSQL_USER", "root"),
      password: ENV.fetch("MYSQL_PASSWORD", "root"),
      database: ENV.fetch("MYSQL_DB", "activerecord_health_test")
    }
  end
end
