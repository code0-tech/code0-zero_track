# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        class TimePartition
          include Comparable

          def self.from_sql(table, partition_name, definition)
            matches = definition.match(/FOR VALUES FROM \('?(?<from>[^)']+)'?\) TO \('?(?<to>[^)']+)'?\)/)

            raise ArgumentError, "Unknown partition definition: #{definition}" unless matches

            raise NotImplementedError, 'MAXVALUE as upper bound is not supported' if matches[:to] == 'MAXVALUE'

            from = matches[:from] == 'MINVALUE' ? nil : matches[:from]
            to = matches[:to]

            new(table, from, to, partition_name: partition_name)
          end

          attr_reader :model, :from, :to, :partition_name

          def initialize(model, from, to, partition_name:)
            @model = model
            @from = date_or_nil(from)
            @to = date_or_nil(to)
            @partition_name = partition_name
          end

          def ==(other)
            model == other.model && partition_name == other.partition_name && from == other.from && to == other.to
          end
          alias eql? ==

          def hash
            [model, partition_name, from, to].hash
          end

          def <=>(other)
            return if model != other.model

            partition_name <=> other.partition_name
          end

          def to_create_sql(connection)
            <<~SQL.squish
              CREATE TABLE IF NOT EXISTS #{fully_qualified_partition(connection)}
              (LIKE #{connection.quote_table_name(model.table_name)} INCLUDING ALL)
            SQL
          end

          def to_attach_sql(connection)
            from_sql = from ? connection.quote(from.to_date.iso8601) : 'MINVALUE'
            to_sql = connection.quote(to.to_date.iso8601)

            <<~SQL.squish
              ALTER TABLE #{connection.quote_table_name(model.table_name)}
              ATTACH PARTITION #{fully_qualified_partition(connection)}
              FOR VALUES FROM (#{from_sql}) TO (#{to_sql})
            SQL
          end

          def to_detach_sql(connection)
            <<~SQL.squish
              ALTER TABLE #{connection.quote_table_name(model.table_name)}
              DETACH PARTITION #{fully_qualified_partition(connection)}
            SQL
          end

          def fully_qualified_partition(connection)
            format(
              '%<schema>s.%<partition>s',
              schema: connection.quote_table_name(
                Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema
              ),
              partition: connection.quote_table_name(partition_name)
            )
          end

          private

          def date_or_nil(obj)
            return unless obj
            return obj if obj.is_a?(Date)

            Date.parse(obj)
          end
        end
      end
    end
  end
end
