# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        module PartitionedTable
          extend ActiveSupport::Concern

          PARTITIONING_STRATEGIES = {
            daily: Partitioning::Strategy::Daily,
            monthly: Partitioning::Strategy::Monthly,
          }.freeze

          class_methods do
            attr_reader :partitioning_strategy

            def partition_by(column, strategy:, **kwargs)
              raise(ArgumentError, 'Table is already partitioned') unless partitioning_strategy.nil?

              strategy_class = PARTITIONING_STRATEGIES[strategy] || raise(
                ArgumentError,
                "Unknown partitioning strategy: #{strategy}"
              )

              @partitioning_strategy = strategy_class.new(self, column, **kwargs)
            end
          end
        end
      end
    end
  end
end
