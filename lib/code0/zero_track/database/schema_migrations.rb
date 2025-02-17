# frozen_string_literal: true

# Heavily inspired by the implementation of GitLab
# (https://gitlab.com/gitlab-org/gitlab/-/blob/7983d2a2203aff265fae479d7c1b7066858d1265/lib/gitlab/database/schema_migrations.rb)
# which is licensed under a modified version of the MIT license which can be found at
# https://gitlab.com/gitlab-org/gitlab/-/blob/7983d2a2203aff265fae479d7c1b7066858d1265/LICENSE
#
# The code might have been modified to accommodate for the needs of this project

module Code0
  module ZeroTrack
    module Database
      module SchemaMigrations
        module_function

        def touch_all(connection)
          context = Database::SchemaMigrations::Context.new(connection)

          # rubocop:disable Rails/SkipsModelValidations -- not an active record object
          Database::SchemaMigrations::Migrations.new(context).touch_all
          # rubocop:enable Rails/SkipsModelValidations
        end

        def load_all(connection)
          context = Database::SchemaMigrations::Context.new(connection)

          Database::SchemaMigrations::Migrations.new(context).load_all
        end
      end
    end
  end
end
