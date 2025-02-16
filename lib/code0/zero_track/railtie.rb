# frozen_string_literal: true

module Code0
  module ZeroTrack
    class Railtie < ::Rails::Railtie
      config.zero_track = ActiveSupport::OrderedOptions.new
      config.zero_track.active_record_timestamps = true

      initializer 'code0.zero_track.inject' do
        Injectors::ActiveRecordTimestamps.inject! if config.zero_track.active_record_timestamps
      end
    end
  end
end
