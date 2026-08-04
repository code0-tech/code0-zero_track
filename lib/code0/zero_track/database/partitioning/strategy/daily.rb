# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        module Strategy
          class Daily < Time
            PARTITION_SUFFIX = 'Y%YM%mD%d'

            def advance_date(date)
              date + 1.day
            end

            def normalize_date(date)
              date.beginning_of_day.to_date
            end

            def partition_name(lower_bound)
              suffix = lower_bound&.strftime(PARTITION_SUFFIX) || 'Y0000M00D00'

              "#{model.table_name}_#{suffix}"
            end

            def default_headroom
              30.days
            end
          end
        end
      end
    end
  end
end
