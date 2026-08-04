# frozen_string_literal: true

require 'zlib'

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        class PartitionManager
          include Loggable

          cattr_accessor :models
          self.models = []

          def self.register_model(clazz)
            models << clazz
          end

          def self.reset_registered_models!
            models.clear
          end

          def self.sync_all_partitions!
            models.each do |model|
              new(model).create_partitions!
            end

            models.reverse_each do |model|
              manager = new(model)
              manager.detach_partitions!
              manager.drop_partitions!
            end
          end

          attr_reader :model

          def initialize(model)
            if model.try(:partitioning_strategy).nil?
              raise ArgumentError, "Model #{model} not configured for partitioning"
            end

            @model = model
          end

          def sync_partitions!
            create_partitions!

            detach_partitions!

            drop_partitions!
          end

          def create_partitions!
            with_lock do |connection|
              model.partitioning_strategy.partitions_to_create.each do |partition|
                create_partition(partition, connection)
                attach_partition(partition, connection)
              end
            end
          end

          def detach_partitions!
            with_lock do |connection|
              model.partitioning_strategy.partitions_to_detach.each do |partition|
                detach_partition(partition, connection)
              end
            end
          end

          def drop_partitions!
            with_lock do |connection|
              model.partitioning_strategy.partitions_to_drop.each do |detached_partition|
                drop_partition(detached_partition, connection)
              end
            end
          end

          private

          def create_partition(partition, connection)
            connection.execute(partition.to_create_sql(connection))
            logger.info(
              message: 'Created new partition',
              table_name: partition.model.table_name,
              partition_name: partition.partition_name
            )
          end

          def attach_partition(partition, connection)
            connection.execute(partition.to_attach_sql(connection))
            logger.info(
              message: 'Attached partition',
              table_name: partition.model.table_name,
              partition_name: partition.partition_name
            )
          end

          def detach_partition(partition, connection)
            connection.execute(partition.to_detach_sql(connection))

            partition_comment = connection.quote({ table: model.table_name, detached_at: Time.current.iso8601 }.to_json)
            fully_qualified_partition = partition.fully_qualified_partition(connection)
            connection.execute("COMMENT ON TABLE #{fully_qualified_partition} IS #{partition_comment}")

            logger.info(
              message: 'Detached partition',
              table_name: partition.model.table_name,
              partition_name: partition.partition_name
            )
          end

          def drop_partition(detached_partition, connection)
            schema_name = connection.quote_table_name(detached_partition.schema)
            partition_name = connection.quote_table_name(detached_partition.name)
            qualified_name = "#{schema_name}.#{partition_name}"
            connection.execute("DROP TABLE #{qualified_name}")

            logger.info(
              message: 'Dropped partition',
              table_name: detached_partition.parent_identifier,
              partition_name: detached_partition.name
            )
          end

          def with_lock
            lock_key = lock_key_for(model.table_name)

            with_connection do |connection|
              connection.transaction do
                connection.execute("SELECT pg_advisory_xact_lock(#{lock_key})")
                yield connection
              end
            end
          end

          def lock_key_for(table_name)
            namespace = 'zero_track:partition_sync'
            Zlib.crc32("#{namespace}:#{table_name}")
          end

          def with_connection(&block)
            model.with_connection(&block)
          end
        end
      end
    end
  end
end
