# frozen_string_literal: true

module Code0
  module ZeroTrack
    class Railtie < ::Rails::Railtie
      config.zero_track = ActiveSupport::OrderedOptions.new
      config.zero_track.active_record = ActiveSupport::OrderedOptions.new
      config.zero_track.active_record.timestamps = true
      config.zero_track.active_record.schema_migrations = true
      config.zero_track.active_record.schema_cleaner = true

      rake_tasks do
        path = File.expand_path(__dir__)
        Dir.glob("#{path}/../../tasks/**/*.rake").each { |f| load f }
      end

      initializer 'code0.zero_track.inject' do
        Injectors::ActiveRecordTimestamps.inject! if config.zero_track.active_record.timestamps
        Injectors::ActiveRecordSchemaMigrations.inject! if config.zero_track.active_record.schema_migrations
      end
    end
  end
end
