# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Injectors
      class ActiveRecordSchemaMigrations
        def self.inject!
          # Patch to write version information as empty files under the db/schema_migrations directory
          # This is intended to reduce potential for merge conflicts in db/structure.sql
          ActiveSupport.on_load(:active_record_postgresqladapter) do
            prepend Database::PostgresqlAdapter::DumpSchemaVersionsMixin
          end
          # Patch to load version information from empty files under the db/schema_migrations directory
          ActiveRecord::Tasks::PostgreSQLDatabaseTasks
            .prepend Database::PostgresqlDatabaseTasks::LoadSchemaVersionsMixin
        end
      end
    end
  end
end
