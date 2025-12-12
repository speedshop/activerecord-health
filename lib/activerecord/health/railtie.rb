# frozen_string_literal: true

module ActiveRecord
  module Health
    class Railtie < Rails::Railtie
      initializer "activerecord_health.validate_configuration" do
        ActiveRecord::Health.configuration.validate!
      end
    end
  end
end
