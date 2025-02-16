# frozen_string_literal: true

require 'rails/railtie'

require 'zeitwerk'
loader = Zeitwerk::Loader.new
loader.tag = File.basename(__FILE__, '.rb')
loader.inflector = Zeitwerk::GemInflector.new(__FILE__)
loader.push_dir(File.expand_path(File.join(__dir__, '..')))
loader.setup

module Code0
  module ZeroTrack
    # Your code goes here...
  end
end

Code0::ZeroTrack::Railtie # eager load the railtie
