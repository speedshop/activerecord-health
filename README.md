# ActiveRecord::Health

Monitor your database's health by tracking active sessions. When load gets too high, shed work to keep your app running.

## Why Use This?

This gem was inspired by [Simon Eskildsen](https://www.youtube.com/watch?v=N8NWDHgWA28), who described a similar system in place at Shopify.

Databases slow down when they have too many active queries. This gem helps you:

- **Shed load safely.** Skip low-priority work when the database is busy.
- **Protect your app.** Return 503 errors instead of timing out, which allows higher-priority work to get through.

The gem counts active database sessions. It compares this count to your database's vCPU count. When active sessions exceed a threshold, the database is "unhealthy."

## Installation

Add to your Gemfile:

```ruby
gem "activerecord-health"
```

Then run:

```bash
bundle install
```

## Quick Start

```ruby
# config/initializers/activerecord_health.rb
ActiveRecord::Health.configure do |config|
  config.vcpu_count = 16        # Required: your database server's vCPU count
  config.cache = Rails.cache    # Required: any ActiveSupport::Cache store
end
```

Now check if your database is healthy:

```ruby
ActiveRecord::Health.ok?
# => true
```

## Configuration

```ruby
ActiveRecord::Health.configure do |config|
  # Required settings
  config.vcpu_count = 16          # Number of vCPUs on your database server
  config.cache = Rails.cache      # Cache store for health check results

  # Optional settings
  config.threshold = 0.75         # Max healthy load (default: 0.75)
  config.cache_ttl = 60           # Cache duration in seconds (default: 60)
end
```

> [!IMPORTANT]
> You must set `vcpu_count` and `cache`. The gem raises an error without them.

### What Does Threshold Mean?

The threshold is the maximum healthy load as a ratio of vCPUs.

With `vcpu_count = 16` and `threshold = 0.75`:
- Up to 12 active sessions = healthy (12/16 = 0.75)
- More than 12 active sessions = unhealthy

## API

### Check Health

```ruby
# Returns true if database is healthy
ActiveRecord::Health.ok?

# Get current load as a percentage
ActiveRecord::Health.load_pct
# => 0.5 (50% of vCPUs in use)
```

### Shed Work

Use `sheddable` to skip work when the database is overloaded:

```ruby
ActiveRecord::Health.sheddable do
  GenerateReport.perform(user_id: current_user.id)
end
```

Use `sheddable_pct` for different priority levels:

```ruby
# High priority: only run below 50% load
ActiveRecord::Health.sheddable_pct(pct: 0.5) do
  BulkImport.perform(data)
end

# Low priority: only run below 90% load
ActiveRecord::Health.sheddable_pct(pct: 0.9) do
  SendAnalyticsEmail.perform(user_id: current_user.id)
end
```

## Usage Examples

### Controller Filter

Return 503 when the database is overloaded:

```ruby
class ReportsController < ApplicationController
  before_action :check_database_health

  private

  def check_database_health
    return if ActiveRecord::Health.ok?
    render json: { error: "Service temporarily unavailable" },
           status: :service_unavailable
  end
end
```

### Sidekiq Middleware

Retry jobs when the database is unhealthy:

```ruby
# config/initializers/sidekiq.rb
class DatabaseHealthMiddleware
  THROTTLED_QUEUES = %w[reports analytics bulk_import].freeze

  def call(_worker, job, _queue)
    if THROTTLED_QUEUES.include?(job["queue"]) && !ActiveRecord::Health.ok?
      raise ActiveRecord::Health::Unhealthy
    end
    yield
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add DatabaseHealthMiddleware
  end
end
```

## Multi-Database Support

Pass the model class that connects to your database:

```ruby
# Check the primary database (default)
ActiveRecord::Health.ok?

# Check a specific database
ActiveRecord::Health.ok?(model: AnimalsRecord)
```

Configure each database separately:

```ruby
ActiveRecord::Health.configure do |config|
  config.vcpu_count = 16  # Default for primary database
  config.cache = Rails.cache

  config.for_model(AnimalsRecord) do |db|
    db.vcpu_count = 8
    db.threshold = 0.5
  end
end
```

## Database Support

| Database | Supported |
|----------|-----------|
| PostgreSQL 10+ | Yes |
| MySQL 5.1+ | Yes |
| MySQL 8.0.22+ | Yes (uses performance_schema) |
| MariaDB | Yes |
| SQLite | No |

## Optional Extensions

Add convenience methods to connections and models:

```ruby
require "activerecord-health/extensions"

ActiveRecord::Base.connection.healthy?
# => true

ActiveRecord::Base.connection.load_pct
# => 0.75

ActiveRecord::Base.database_healthy?
# => true
```

## Known Issues

This gem is simple by design. Keep these limits in mind:

- **Errors look like overload.** The health check query can fail for many reasons: network problems, DNS issues, or connection pool limits. When this happens, the gem marks the database as unhealthy. It caches this result for `cache_ttl` seconds. This can cause load shedding even when the database is fine.
- **Session counts can be wrong.** The gem assumes many active sessions means the CPU is busy. But sessions can be active while waiting on locks, disk reads, or slow clients. The database may have room to spare, but the gem still reports it as unhealthy.

## License

MIT License. See [LICENSE](LICENSE.txt) for details.
