# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        class PostgresPartitionedTable < Rails.application.config.zero_track.db_partitioning.base_ar_class.constantize
          self.table_name = 'postgres_partitioned_tables'
          self.primary_key = 'identifier'

          def readonly?
            true
          end

          has_many :postgres_partitions,
                   class_name: 'Code0::ZeroTrack::Database::Partitioning::PostgresPartition',
                   foreign_key: 'parent_identifier',
                   primary_key: 'identifier',
                   inverse_of: :postgres_partitioned_table

          has_many :postgres_detached_partitions,
                   class_name: 'Code0::ZeroTrack::Database::Partitioning::PostgresDetachedPartition',
                   foreign_key: 'parent_identifier',
                   primary_key: 'identifier',
                   inverse_of: :postgres_partitioned_table
        end
      end
    end
  end
end
