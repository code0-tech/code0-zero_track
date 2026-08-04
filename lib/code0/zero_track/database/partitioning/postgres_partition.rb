# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        class PostgresPartition < Rails.application.config.zero_track.db_partitioning.base_ar_class.constantize
          self.table_name = 'postgres_partitions'
          self.primary_key = 'identifier'

          def readonly?
            true
          end

          belongs_to :postgres_partitioned_table,
                     class_name: 'Code0::ZeroTrack::Database::Partitioning::PostgresPartitionedTable',
                     foreign_key: 'parent_identifier',
                     primary_key: 'identifier',
                     inverse_of: :postgres_partitions
        end
      end
    end
  end
end
