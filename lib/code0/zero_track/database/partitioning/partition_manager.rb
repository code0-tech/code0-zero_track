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

              drop_declared_foreign_keys_from_detached_partitions(connection)
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

          def drop_declared_foreign_keys_from_detached_partitions(connection)
            constraint_names = model.foreign_keys_to_drop_on_detach || []
            return if constraint_names.empty?

            warn_about_unknown_foreign_keys(constraint_names, connection)

            detached_foreign_keys(constraint_names, connection).each do |qualified_table, constraint_name|
              connection.execute(
                "ALTER TABLE #{qualified_table} " \
                "DROP CONSTRAINT #{connection.quote_column_name(constraint_name)}"
              )

              logger.info(
                message: 'Dropped foreign key from detached partition',
                table_name: model.table_name,
                partition_name: qualified_table,
                constraint_name: constraint_name
              )
            end
          end

          # We check the parent table because we drop the FK from the partition
          # when detaching. A missing FK on the detached partition is an expected state
          def warn_about_unknown_foreign_keys(constraint_names, connection)
            existing = parent_foreign_key_names(connection)
            unknown = constraint_names - existing
            return if unknown.empty?

            logger.warn(
              message: 'Configured foreign keys to drop on detach do not exist on the partitioned table',
              table_name: model.table_name,
              constraint_names: unknown
            )
          end

          def parent_foreign_key_names(connection)
            connection.select_values(<<~SQL.squish)
              SELECT con.conname
              FROM pg_catalog.pg_constraint con
              WHERE con.contype = 'f'
                AND con.conrelid = #{connection.quote(model.table_name)}::regclass
            SQL
          end

          def detached_foreign_keys(constraint_names, connection)
            schema = Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema
            quoted_names = constraint_names.map { |name| connection.quote(name) }.join(', ')

            rows = connection.select_rows(<<~SQL.squish)
              SELECT (quote_ident(n.nspname) || '.' || quote_ident(c.relname)) AS qualified_table,
                     con.conname AS constraint_name
              FROM pg_catalog.pg_constraint con
              JOIN pg_catalog.pg_class c ON c.oid = con.conrelid
              JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
              WHERE con.contype = 'f'
                AND con.conname IN (#{quoted_names})
                AND n.nspname = #{connection.quote(schema)}
                AND c.relkind = 'r'
                AND NOT c.relispartition
                AND NOT EXISTS (
                  SELECT 1 FROM pg_catalog.pg_inherits i WHERE i.inhrelid = c.oid
                )
            SQL

            rows.map { |qualified_table, constraint_name| [qualified_table, constraint_name] }
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
