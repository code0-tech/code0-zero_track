# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Code0::ZeroTrack::Loggable do
  let(:clazz) do
    Class.new do
      include Code0::ZeroTrack::Loggable
    end
  end

  context 'with named class' do
    before do
      stub_const('TestClass', clazz)
    end

    it 'for instantiated class' do
      TestClass.new.logger.with_context do |context|
        expect(context.to_h).to include(Code0::ZeroTrack::Context.log_key(:class) => 'TestClass')
      end
    end

    it 'when called on the class' do
      TestClass.logger.with_context do |context|
        expect(context.to_h).to include(Code0::ZeroTrack::Context.log_key(:class) => 'TestClass')
      end
    end
  end

  context 'with anonymous class' do
    it 'for instantiated class' do
      clazz.new.logger.with_context do |context|
        expect(context.to_h).to include(Code0::ZeroTrack::Context.log_key(:class) => '<Anonymous>')
      end
    end

    it 'when called on the class' do
      clazz.logger.with_context do |context|
        expect(context.to_h).to include(Code0::ZeroTrack::Context.log_key(:class) => '<Anonymous>')
      end
    end
  end
end
