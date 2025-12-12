# frozen_string_literal: true

require "activerecord/health/extensions"

if defined?(::ActiveRecord::ConnectionAdapters::AbstractAdapter)
  ::ActiveRecord::ConnectionAdapters::AbstractAdapter.include(
    ::ActiveRecord::Health::ConnectionExtension
  )
end

if defined?(::ActiveRecord::Base)
  ::ActiveRecord::Base.extend(::ActiveRecord::Health::ModelExtension)
end
