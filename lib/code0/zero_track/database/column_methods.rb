# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module ColumnMethods
        module Timestamps
          # Appends columns `created_at` and `updated_at` to a table.
          #
          # It is used in table creation like:
          # create_table 'users' do |t|
          #   t.timestamps_with_timezone
          # end
          def timestamps_with_timezone(**options)
            options[:null] = false if options[:null].nil?

            %i[created_at updated_at].each do |column_name|
              column(column_name, :datetime_with_timezone, **options)
            end
          end

          # Adds specified column with appropriate timestamp type
          #
          # It is used in table creation like:
          # create_table 'users' do |t|
          #   t.datetime_with_timezone :did_something_at
          # end
          def datetime_with_timezone(column_name, **options)
            column(column_name, :datetime_with_timezone, **options)
          end
        end
      end
    end
  end
end
