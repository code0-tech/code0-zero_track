# frozen_string_literal: true

module Code0
  module ZeroTrack
    class Railtie < ::Rails::Railtie
      config.zero_track = ActiveSupport::OrderedOptions.new
      config.zero_track.active_record = ActiveSupport::OrderedOptions.new
      config.zero_track.active_record.timestamps = false
      config.zero_track.active_record.schema_migrations = false
      config.zero_track.active_record.schema_cleaner = false

      rake_tasks do
        path = File.expand_path(__dir__)
        Dir.glob("#{path}/../../tasks/**/*.rake").each { |f| load f }
      end

      config.after_initialize do
        Injectors::ActiveRecordTimestamps.inject! if config.zero_track.active_record.timestamps
        Injectors::ActiveRecordSchemaMigrations.inject! if config.zero_track.active_record.schema_migrations
      end
    end
  end
end
