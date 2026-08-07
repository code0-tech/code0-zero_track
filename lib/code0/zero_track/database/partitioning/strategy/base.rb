# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        module Strategy
          class Base
            attr_reader :model, :partitioning_column, :headroom, :retain_for, :retain_detached_for

            def initialize(
              model,
              partitioning_column,
              headroom: default_headroom,
              retain_for: nil,
              retain_detached_for: 7.days
            )
              @model = model
              @partitioning_column = partitioning_column
              @headroom = headroom
              @retain_for = retain_for
              @retain_detached_for = retain_detached_for
            end

            def current_partitions
              raise NotImplementedError
            end

            def desired_partitions
              raise NotImplementedError
            end

            def oldest_active_date
              raise NotImplementedError
            end

            def partition_name(lower_bound)
              raise NotImplementedError
            end

            def default_headroom
              raise NotImplementedError
            end

            def partitions_to_create
              desired_partitions - current_partitions
            end

            def partitions_to_detach
              current_partitions - desired_partitions
            end

            def partitions_to_drop
              partitioned_table = PostgresPartitionedTable.find_by(identifier: model.table_name)

              if partitioned_table.nil?
                logger.warn(message: 'Failed to find partitioned table', identifier: model.table_name)
                return []
              end

              partitioned_table.postgres_detached_partitions.detached_before(retain_detached_for.ago)
            end

            def retention_enabled?
              retain_for.present?
            end
          end
        end
      end
    end
  end
end
