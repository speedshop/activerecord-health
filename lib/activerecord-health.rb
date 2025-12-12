ActiveSupport.on_load(:active_record) do
  require "activerecord/health"
end
