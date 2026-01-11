# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module SchemaMigrations
        class Formatter
          def initialize(connection)
            @connection = connection
          end

          def format(_)
            # rubocop:disable Rails/SkipsModelValidations -- not an active record object
            Database::SchemaMigrations.touch_all(@connection) unless Rails.env.production?
            # rubocop:enable Rails/SkipsModelValidations
            nil
          end
        end
      end
    end
  end
end
