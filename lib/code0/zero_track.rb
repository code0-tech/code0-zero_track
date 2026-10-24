# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'
require 'rails/railtie'

require 'zeitwerk'
loader = Zeitwerk::Loader.new
loader.tag = 'code0-zero_track'
loader.inflector = Zeitwerk::GemInflector.new(__FILE__)
loader.push_dir(File.expand_path(File.join(__dir__, '..')))

# ignore feature entrypoints
loader.ignore("#{__dir__}/zero_track/features")

# database partitioning is a separate feature which needs to be explicitly required
loader.ignore("#{__dir__}/zero_track/database/partitioning")

loader.setup

module Code0
  module ZeroTrack
    # Your code goes here...
  end
end

Code0::ZeroTrack::Railtie # eager load the railtie
