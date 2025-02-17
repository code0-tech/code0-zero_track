# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Injectors
      class ActiveRecordTimestamps
        def self.inject!
          ActiveSupport.on_load(:active_record_postgresqladapter) do
            self::NATIVE_DATABASE_TYPES[:datetime_with_timezone] = { name: 'timestamptz' }
          end

          ActiveSupport.on_load(:active_record) do
            ActiveRecord::Base.time_zone_aware_types += [:datetime_with_timezone]
          end

          ActiveRecord::ConnectionAdapters::ColumnMethods.include ZeroTrack::Database::ColumnMethods::Timestamps
        end
      end
    end
  end
end
