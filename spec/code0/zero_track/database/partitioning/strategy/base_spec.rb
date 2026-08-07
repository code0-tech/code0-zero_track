# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/VerifiedDoubles -- AR models require a DB connection for verification.
RSpec.describe Code0::ZeroTrack::Database::Partitioning::Strategy::Base do
  let(:model) { double('Model', table_name: 'events') }

  describe '#initialize' do
    it 'requires headroom since default_headroom is abstract' do
      expect { described_class.new(model, :created_at) }.to raise_error(NotImplementedError)
    end

    it 'stores configuration' do
      strategy = described_class.new(model, :created_at, headroom: 1.day, retain_for: 90.days,
                                                         retain_detached_for: 14.days)

      expect(strategy.model).to eq(model)
      expect(strategy.partitioning_column).to eq(:created_at)
      expect(strategy.headroom).to eq(1.day)
      expect(strategy.retain_for).to eq(90.days)
      expect(strategy.retain_detached_for).to eq(14.days)
    end

    it 'defaults retain_for to nil and retain_detached_for to 7 days' do
      strategy = described_class.new(model, :created_at, headroom: 1.day)

      expect(strategy.retain_for).to be_nil
      expect(strategy.retain_detached_for).to eq(7.days)
    end
  end

  describe '#retention_enabled?' do
    it 'returns false when retain_for is not set' do
      strategy = described_class.new(model, :created_at, headroom: 1.day)

      expect(strategy.retention_enabled?).to be(false)
    end

    it 'returns true when retain_for is set' do
      strategy = described_class.new(model, :created_at, headroom: 1.day, retain_for: 90.days)

      expect(strategy.retention_enabled?).to be(true)
    end
  end

  describe '#partitions_to_drop' do
    it 'returns detached partitions older than retain_detached_for' do
      strategy = described_class.new(model, :created_at, headroom: 1.day, retain_detached_for: 7.days)

      partitioned_table = double('PostgresPartitionedTable')
      detached_partitions_relation = double('relation')
      old_partitions = [double('old_partition')]

      allow(Code0::ZeroTrack::Database::Partitioning::PostgresPartitionedTable)
        .to receive(:find_by).with(identifier: 'events').and_return(partitioned_table)
      allow(partitioned_table).to receive(:postgres_detached_partitions).and_return(detached_partitions_relation)
      allow(detached_partitions_relation).to receive(:detached_before).and_return(old_partitions)

      expect(strategy.partitions_to_drop).to eq(old_partitions)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
