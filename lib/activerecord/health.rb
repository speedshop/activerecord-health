# frozen_string_literal: true

require_relative "health/version"
require_relative "health/configuration"
require_relative "health/adapters/postgresql_adapter"
require_relative "health/adapters/mysql_adapter"
require_relative "health/railtie" if defined?(Rails::Railtie)

module ActiveRecord
  module Health
    QUERY_TIMEOUT = 1

    class << self
      def configure
        yield(configuration)
      end

      def configuration
        @configuration ||= Configuration.new
      end

      def reset_configuration!
        @configuration = nil
      end

      def ok?(model: ActiveRecord::Base)
        load_pct(model: model) <= config_for(model).threshold
      end

      def load_pct(model: ActiveRecord::Base)
        db_config_name = model.connection_db_config.name
        cache_key = "activerecord_health:load_pct:#{db_config_name}"

        read_from_cache(cache_key) { query_load_pct(model) }
      end

      def sheddable(model: ActiveRecord::Base)
        return false unless ok?(model: model)
        yield
        true
      end

      def sheddable_pct(pct:, model: ActiveRecord::Base)
        return false if load_pct(model: model) > pct
        yield
        true
      end

      private

      def config_for(model)
        model_class = model.is_a?(Class) ? model : model.class
        configuration.for_model(model_class)
      end

      def read_from_cache(cache_key)
        configuration.cache.read(cache_key) || write_to_cache(cache_key, yield)
      rescue
        0.0
      end

      def write_to_cache(cache_key, value)
        configuration.cache.write(cache_key, value, expires_in: configuration.cache_ttl)
        value
      end

      def query_load_pct(model)
        active_sessions = fetch_active_sessions(model)
        calculate_and_instrument_load(model, active_sessions)
      rescue
        1.0
      end

      def fetch_active_sessions(model)
        adapter = adapter_for(model.connection)
        execute_with_timeout(model.connection, adapter, adapter.active_session_count_query)
      end

      def calculate_and_instrument_load(model, active_sessions)
        load_pct = active_sessions.to_f / config_for(model).vcpu_count
        instrument(model.connection_db_config.name, load_pct, active_sessions)
        load_pct
      end

      def execute_with_timeout(connection, adapter, query)
        adapter.execute_with_timeout(connection, query, QUERY_TIMEOUT)
      end

      def adapter_for(connection)
        adapter_class_for(connection).build(connection)
      end

      def adapter_class_for(connection)
        case connection.adapter_name.downcase
        when /postgresql/ then Adapters::PostgreSQLAdapter
        when /mysql/, /trilogy/ then Adapters::MySQLAdapter
        else raise "Unsupported database adapter: #{connection.adapter_name}"
        end
      end

      def instrument(db_config_name, load_pct, active_sessions)
        return unless defined?(ActiveSupport::Notifications)

        ActiveSupport::Notifications.instrument(
          "health_check.activerecord_health",
          database: db_config_name,
          load_pct: load_pct,
          active_sessions: active_sessions
        )
      end
    end
  end
end
