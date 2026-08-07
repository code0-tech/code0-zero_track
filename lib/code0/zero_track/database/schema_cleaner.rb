# frozen_string_literal: true

# Heavily inspired by the implementation of GitLab
# (https://gitlab.com/gitlab-org/gitlab/-/blob/7983d2a2203aff265fae479d7c1b7066858d1265/lib/gitlab/database/schema_cleaner.rb)
# which is licensed under a modified version of the MIT license which can be found at
# https://gitlab.com/gitlab-org/gitlab/-/blob/7983d2a2203aff265fae479d7c1b7066858d1265/LICENSE
#
# The code might have been modified to accommodate for the needs of this project

module Code0
  module ZeroTrack
    module Database
      class SchemaCleaner
        attr_reader :original_schema

        def initialize(original_schema)
          @original_schema = original_schema
        end

        def clean(io)
          structure = original_schema.dup

          # Remove noise
          structure.gsub!(/^COMMENT ON EXTENSION.*/, '')
          structure.gsub!(/^SET.+/, '')
          structure.gsub!(/^SELECT pg_catalog\.set_config\('search_path'.+/, '')
          structure.gsub!(/^--.*/, "\n")

          # We typically don't assume we're working with the public schema.
          # pg_dump uses fully qualified object names though, since we have multiple schemas
          # in the database.
          #
          # The intention here is to not introduce an assumption about the standard schema,
          # unless we have a good reason to do so.
          structure.gsub!(/public\.(\w+)/, '\1')
          structure.gsub!(
            /CREATE EXTENSION IF NOT EXISTS (\w+) WITH SCHEMA public;/,
            'CREATE EXTENSION IF NOT EXISTS \1;'
          )

          # Remove dynamic partition objects that are managed automatically at runtime.
          # These would cause schema drift on every partition rotation if left in the dump.
          remove_dynamic_partitions!(structure)

          structure.gsub!(/\n{3,}/, "\n\n")

          io << structure.strip
          io << "\n"

          nil
        end

        private

        def dynamic_partition_schema
          Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema
        end

        def remove_dynamic_partitions!(structure)
          schema = Regexp.escape(dynamic_partition_schema)

          # Remove CREATE TABLE <schema>.<partition> (...);
          structure.gsub!(/^CREATE TABLE #{schema}\.\S+\s*\(.*?\);\n/m, '')

          # Remove ALTER TABLE ... ATTACH PARTITION <schema>.<partition> ...;
          structure.gsub!(/^ALTER TABLE .+ ATTACH PARTITION #{schema}\.\S+.*?;\n/, '')

          # Remove ALTER TABLE ONLY <schema>.<partition> ...;
          structure.gsub!(/^ALTER TABLE ONLY #{schema}\.\S+\n.*?;\n/m, '')

          # Remove CREATE [UNIQUE] INDEX ... ON <schema>.<partition> ...;
          structure.gsub!(/^CREATE (?:UNIQUE )?INDEX \S+ ON #{schema}\.\S+.*?;\n/m, '')

          # Remove ALTER INDEX ... ATTACH PARTITION <schema>.<partition>;
          structure.gsub!(/^ALTER INDEX \S+ ATTACH PARTITION #{schema}\.\S+;\n/, '')
        end
      end
    end
  end
end
