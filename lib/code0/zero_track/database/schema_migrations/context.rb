# frozen_string_literal: true

# Heavily inspired by the implementation of GitLab
# (https://gitlab.com/gitlab-org/gitlab/-/blob/7983d2a2203aff265fae479d7c1b7066858d1265/lib/gitlab/database/schema_migrations/context.rb)
# which is licensed under a modified version of the MIT license which can be found at
# https://gitlab.com/gitlab-org/gitlab/-/blob/7983d2a2203aff265fae479d7c1b7066858d1265/LICENSE
#
# The code might have been modified to accommodate for the needs of this project

module Code0
  module ZeroTrack
    module Database
      module SchemaMigrations
        class Context
          attr_reader :connection

          class_attribute :default_schema_migrations_path, default: 'db/schema_migrations'

          def initialize(connection)
            @connection = connection
          end

          def schema_directory
            @schema_directory ||= Rails.root.join(database_schema_migrations_path).to_s
          end

          def versions_to_create
            versions_from_database = @connection.pool.schema_migration.versions
            versions_from_migration_files = @connection.pool.migration_context.migrations.map { |m| m.version.to_s }

            versions_from_database & versions_from_migration_files
          end

          private

          def database_name
            @database_name ||= @connection.pool.db_config.name
          end

          def database_schema_migrations_path
            @connection.pool.db_config.configuration_hash[:schema_migrations_path] ||
              self.class.default_schema_migrations_path
          end
        end
      end
    end
  end
end
