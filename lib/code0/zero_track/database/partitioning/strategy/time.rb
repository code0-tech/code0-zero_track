# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        module Strategy
          class Time < Base
            include Loggable

            def current_partitions
              partitioned_table = PostgresPartitionedTable.find_by(identifier: model.table_name)

              if partitioned_table.nil?
                logger.warn(message: 'Failed to find partitioned table', identifier: model.table_name)
                return []
              end

              partitioned_table.postgres_partitions.map do |partition|
                TimePartition.from_sql(model, partition.name, partition.condition)
              end
            end

            def desired_partitions
              partitions = []

              min_date, max_date = desired_range

              while min_date < max_date
                next_date = advance_date(min_date)

                partitions << TimePartition.new(
                  model,
                  min_date,
                  next_date,
                  partition_name: partition_name(min_date)
                )

                min_date = next_date
              end

              partitions
            end

            def desired_range
              if retention_enabled?
                min_date = oldest_active_date
              else
                first_partition = current_partitions.min

                min_date = first_partition.from || first_partition.to if first_partition
                min_date ||= Date.current
              end

              min_date = normalize_date(min_date)

              max_date = advance_date(Date.current) + headroom

              [min_date, max_date]
            end

            def oldest_active_date
              normalize_date(retain_for.ago)
            end

            def advance_date(date)
              raise NotImplementedError
            end

            def normalize_date(date)
              raise NotImplementedError
            end
          end
        end
      end
    end
  end
end
