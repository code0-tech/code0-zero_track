# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Injectors
      class ActiveRecordSchemaMigrations
        def self.inject!(config)
          if Rails.gem_version >= Gem::Version.create('8.1')
            config.active_record.schema_versions_formatter = Database::SchemaMigrations::Formatter
          else
            # Patch to write version information as empty files under the db/schema_migrations directory
            # This is intended to reduce potential for merge conflicts in db/structure.sql
            ActiveSupport.on_load(:active_record_postgresqladapter) do
              prepend Database::PostgresqlAdapter::DumpSchemaVersionsMixin
            end
          end

          # Patch to load version information from empty files under the db/schema_migrations directory
          ActiveRecord::Tasks::PostgreSQLDatabaseTasks
            .prepend Database::PostgresqlDatabaseTasks::LoadSchemaVersionsMixin
        end
      end
    end
  end
end
