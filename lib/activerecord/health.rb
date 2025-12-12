# frozen_string_literal: true

require_relative "health/version"
require_relative "health/configuration"
require_relative "health/adapters/postgresql_adapter"
require_relative "health/adapters/mysql_adapter"

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
        cached_value = configuration.cache.read(cache_key)
        return cached_value unless cached_value.nil?

        value = yield
        configuration.cache.write(cache_key, value, expires_in: configuration.cache_ttl)
        value
      rescue
        0.0
      end

      def query_load_pct(model)
        connection = model.connection
        adapter = adapter_for(connection)
        config = config_for(model)

        active_sessions = execute_with_timeout(connection, adapter.active_session_count_query)
        active_sessions.to_f / config.vcpu_count
      rescue
        1.0
      end

      def execute_with_timeout(connection, query)
        adapter_name = connection.adapter_name.downcase

        case adapter_name
        when /postgresql/
          execute_with_postgresql_timeout(connection, query)
        when /mysql/
          execute_with_mysql_timeout(connection, query)
        else
          connection.select_value(query)
        end
      end

      def execute_with_postgresql_timeout(connection, query)
        connection.transaction do
          connection.execute("SET LOCAL statement_timeout = '#{QUERY_TIMEOUT}s'")
          connection.select_value(query)
        end
      end

      def execute_with_mysql_timeout(connection, query)
        connection.transaction do
          connection.execute("SET max_execution_time = #{QUERY_TIMEOUT * 1000}")
          connection.select_value(query)
        end
      end

      def adapter_for(connection)
        case connection.adapter_name.downcase
        when /postgresql/
          Adapters::PostgreSQLAdapter.new
        when /mysql/
          version = connection.select_value("SELECT VERSION()")
          Adapters::MySQLAdapter.new(version)
        else
          raise "Unsupported database adapter: #{connection.adapter_name}"
        end
      end
    end
  end
end
