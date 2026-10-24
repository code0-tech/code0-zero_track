# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        class Engine < Rails::Engine
          isolate_namespace Partitioning

          config.zero_track.db_partitioning = ActiveSupport::OrderedOptions.new
          config.zero_track.db_partitioning.dynamic_partition_schema = 'partitions_dynamic'
          config.zero_track.db_partitioning.base_ar_class = 'ActiveRecord::Base'

          initializer 'code0-zero_track.database_partitioning.paths' do
            paths['db/migrate'] = 'db/migrate/database_partitioning'
          end

          initializer 'code0-zero_track.database_partitioning.register_schema_cleaner' do
            config.zero_track.active_record.schema_cleaner_callbacks << SchemaCleaner.new
          end
        end
      end
    end
  end
end
