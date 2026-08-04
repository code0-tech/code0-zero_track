# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module Partitioning
        module Strategy
          class Monthly < Time
            PARTITION_SUFFIX = 'Y%YM%m'

            def advance_date(date)
              date.next_month
            end

            def normalize_date(date)
              date.beginning_of_month.to_date
            end

            def partition_name(lower_bound)
              suffix = lower_bound&.strftime(PARTITION_SUFFIX) || 'Y0000M00'

              "#{model.table_name}_#{suffix}"
            end

            def default_headroom
              6.months
            end
          end
        end
      end
    end
  end
end
