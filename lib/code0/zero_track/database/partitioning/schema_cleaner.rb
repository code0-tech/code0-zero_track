# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        class SchemaCleaner
          def clean!(structure)
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

            # Remove COMMENT ON TABLE <schema>.<partition> IS '<comment>';
            structure.gsub!(/^COMMENT ON TABLE #{schema}\.\S+ IS .*;\n/, '')
          end

          private

          def dynamic_partition_schema
            Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema
          end
        end
      end
    end
  end
end
