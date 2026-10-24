# frozen_string_literal: true

require 'code0/zero_track'

loader = Zeitwerk::Loader.new
loader.tag = 'code0-zero_track/database_partitioning'
loader.inflector = Zeitwerk::GemInflector.new(File.join(__dir__, '../..'))

module Code0
  module ZeroTrack
    module Database
      module Partitioning
      end
    end
  end
end

loader.push_dir(
  File.expand_path(File.join(__dir__, '../database/partitioning')),
  namespace: Code0::ZeroTrack::Database::Partitioning
)

loader.setup

Code0::ZeroTrack::Database::Partitioning::Engine # eager load the engine
