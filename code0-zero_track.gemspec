# frozen_string_literal: true

require_relative 'lib/code0/zero_track/version'

Gem::Specification.new do |spec|
  spec.name        = 'code0-zero_track'
  spec.version     = Code0::ZeroTrack::VERSION
  spec.authors     = ['Niklas van Schrick']
  spec.email       = ['mc.taucher2003@gmail.com']
  spec.homepage    = 'https://github.com/code0-tech/code0-zero_track'
  spec.summary     = 'Common helpers for Code0 rails applications'
  spec.license     = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/releases"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'rails', '>= 8.0.1'
  spec.add_dependency 'zeitwerk', '~> 2.7'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-parameterized', '~> 1.0'
  spec.add_development_dependency 'rspec-rails', '~> 7.0'
  spec.add_development_dependency 'rubocop-rails', '~> 2.19'
  spec.add_development_dependency 'rubocop-rake', '~> 0.7.0'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop-rspec_rails', '~> 2.30'
end
