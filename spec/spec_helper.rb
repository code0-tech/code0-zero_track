# frozen_string_literal: true

require 'code0/zero_track'

# these requires are necessary because without them, requiring rspec/rails fails
require 'action_view'
require 'action_dispatch'
require 'action_controller'

require 'rspec/rails'

require 'rails/all'

require 'rspec-parameterized'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.define_derived_metadata do |metadata|
    metadata[:aggregate_failures] = true
  end
end
