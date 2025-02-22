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