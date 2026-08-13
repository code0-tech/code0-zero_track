# Code0::ZeroTrack

ZeroTrack is a Ruby gem designed to accelerate and standardize Rails development for Code0 projects.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "code0-zero_track"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install code0-zero_track
```

## Features

### `Code0::ZeroTrack::Context`

Context allows you to save data in a thread local object. Data from the Context is merged into the
log messages, if `Code0::ZeroTrack::Logs::JsonFormatter` or `Code0::ZeroTrack::Logs::JsonFormatter::Tagged`
is used.

`.with_context(data, &block)` creates a new context inheriting data from the previous context and adds the
passed data to it. The new context is dropped after the block finished execution. \
`.push(data)` creates a new context inheriting data from the previous context and adds the passed data to it. \
`.current` returns the context from the top of the stack.

### `Code0::ZeroTrack::Memoize`

This module can be included to get access to the `memoize(name, reset_on_change, &block)` method.

This method allows to memoize a value, so it only gets computed once.
Each memoize is identified by the name. You can pass a proc to `reset_on_change` and the memoization
will automatically clear every time returned value changes.

`memoized?(name)` allows to check if a value for the given name is currently memoized. \
Memoizations can be cleared with `clear_memoize(name)` or `clear_memoize!(name)`.

### `config.zero_track.active_record.schema_cleaner`

When using `config.active_record.schema_format = :sql`, Rails produces a `db/structure.sql`.
This file contains a lot of noise that doesn't provide much value.

This noise can be cleaned out with `config.zero_track.active_record.schema_cleaner = true`.

### `config.zero_track.active_record.timestamps`

Setting `config.zero_track.active_record.timestamps = true` adds `timestamps_with_timezone`
and `datetime_with_timezone` as methods on the table model when creating tables in migrations.

They behave just like `timestamps` and `datetime`, just including timezones.

### `config.zero_track.active_record.schema_migrations`

Rails uses the `schema_migrations` table to keep track which migrations have been executed.
This information is also persisted in the `db/structure.sql`, so the `schema_migrations` table
can be filled with the correct entries when the schema is loaded from the schema file.

This approach is prone to git conflicts, so you can switch to a file based persistence
with `config.zero_track.active_record.schema_migrations = true`. Instead of an `INSERT INTO` in
the `db/structure.sql`, this mode creates files in the `db/schema_migrations` directory.

### Table Partitioning

PostgreSQL supports declarative table partitioning. The partition manager automates the
management of partitions without manual operations or extensions on the PostgreSQL server.

#### Configuration

```ruby
config.zero_track.db_partitioning.dynamic_partition_schema = 'partitions_dynamic' # default
config.zero_track.db_partitioning.base_ar_class = 'ActiveRecord::Base' # default
```

- `dynamic_partition_schema`: The PostgreSQL schema where dynamic partitions are stored.
- `base_ar_class`: The ActiveRecord base class used for the internal partitioning models.

#### Migration Helpers

Include the migration helpers by inheriting from `Code0::ZeroTrack::Database::Migration[1.0]` (or the
appropriate version). The following methods become available:

`create_partition_by_date_table(table_name, partition_column:, primary_key: nil, **options, &block)` creates a table
partitioned by range on the given column. By default, it adds a `bigserial` id column and sets up a composite
primary key of `(id, partition_column)`. If `primary_key` is provided (e.g. `primary_key: %i[date other_column]`),
the id column is omitted and the given columns are used as the primary key instead.

`create_dynamic_partition_schema` / `drop_dynamic_partition_schema` creates or drops the schema
used for storing dynamic partitions.

`create_partitioning_views` / `drop_partitioning_views` creates or drops the PostgreSQL views
(`postgres_partitioned_tables`, `postgres_partitions`, `postgres_detached_partitions`) that the
partition manager uses to inspect existing partitions.

Example migration:

```ruby
class CreatePartitionedEvents < Code0::ZeroTrack::Database::Migration[1.0]
  def change
    create_dynamic_partition_schema
    create_partitioning_views

    create_partition_by_date_table :events, partition_column: :created_at do |t|
      t.text :name, null: false
      t.timestamps_with_timezone null: false
    end
  end
end
```

The schema and views only need to be created once before creating the first partitioned table.

Tables don't necessarily have to be created with the provided helper. The partition manager will
work as long as the model is correctly configured.

#### Defining a Partitioned Model

Include `Code0::ZeroTrack::Database::Partitioning::PartitionedTable` in your model and declare
the partitioning strategy:

```ruby
class Event < ApplicationRecord
  include Code0::ZeroTrack::Database::Partitioning::PartitionedTable

  partition_by :created_at, strategy: :monthly, retain_for: 12.months
end
```

Available strategies: `:daily` and `:monthly`.

Options passed to `partition_by`:

| Option | Description | Default |
|--------|-------------|---------|
| `strategy` | `:daily` or `:monthly` | *required* |
| `headroom` | How far ahead to pre-create partitions | 30 days (daily) / 6 months (monthly) |
| `retain_for` | How long to keep partitions before detaching (enables retention) | `nil` (disabled) |
| `retain_detached_for` | How long to keep detached partitions before dropping | 7 days |

#### Partition Manager

Register models for automatic partition management:

```ruby
Code0::ZeroTrack::Database::Partitioning::PartitionManager.register_model(Event)
Code0::ZeroTrack::Database::Partitioning::PartitionManager.register_model(EventDetail)
```

Then synchronize all registered models. The gem won't run this for you.
Call it from a cron job, Sidekiq scheduler, or deploy script:

```ruby
Code0::ZeroTrack::Database::Partitioning::PartitionManager.sync_all_partitions!
```

Or manage a single model:

```ruby
manager = Code0::ZeroTrack::Database::Partitioning::PartitionManager.new(Event)
manager.sync_partitions!
```

`sync_all_partitions!` first creates partitions for all registered models, then detaches and drops
partitions for all models in reverse registration order.

`sync_partitions!` performs three operations in order for a single model:
1. Create and attach new partitions to cover the desired range (up to the configured headroom).
2. Detach partitions that fall outside the desired range (when retention is enabled).
3. Drop detached partitions that have been detached longer than `retain_detached_for`.

If needed, the three phases can be called individually with `create_partitions!`, `detach_partitions!`
and `drop_partitions!`. This only works on a partition manager for a specific model. There is no
shortcut to run this on all registered models like the `sync_all_partitions!` method.

Each table gets a PostgreSQL advisory lock, so concurrent calls won't conflict.

When tables have foreign key relationships, registration order and retention configuration matter:

- Register parent tables before child tables. `sync_all_partitions!` creates partitions in
  registration order and detaches/drops them in reverse order. This way the parent tables
  are created before the children and dropped after their children.
- A child table's `retain_for` must be less than or equal to the parent table's `retain_for`.
  If a child retains partitions longer than its parent, dropping the parent partition will
  fail because the child's foreign key still references it.

#### Schema Cleaner Integration

Dynamic partition tables are automatically removed from `db/structure.sql` if the
[schema cleaner](#configzero_trackactive_recordschema_cleaner) is enabled.
