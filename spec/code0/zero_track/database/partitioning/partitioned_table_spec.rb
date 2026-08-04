# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/VerifiedDoubles -- AR models require a DB connection for verification.
RSpec.describe Code0::ZeroTrack::Database::Partitioning::PartitionedTable do
  let(:test_class) do
    Class.new(ActiveRecord::Base) do # rubocop:disable Rails/ApplicationRecord
      self.table_name = 'test_partitioned'
      include Code0::ZeroTrack::Database::Partitioning::PartitionedTable
    end
  end

  let(:partitioned_table) { double('PostgresPartitionedTable') }
  let(:postgres_partitions_relation) { double('relation') }

  before do
    allow(Code0::ZeroTrack::Database::Partitioning::PostgresPartitionedTable)
      .to receive(:find_by).and_return(partitioned_table)
    allow(partitioned_table).to receive(:postgres_partitions).and_return(postgres_partitions_relation)
    allow(postgres_partitions_relation).to receive(:map).and_return([])
  end

  describe '.partition_by' do
    it 'configures the model with a daily strategy' do
      test_class.partition_by(:created_at, strategy: :daily)

      expect(test_class.partitioning_strategy).to be_a(
        Code0::ZeroTrack::Database::Partitioning::Strategy::Daily
      )
      expect(test_class.partitioning_strategy.partitioning_column).to eq(:created_at)
    end

    it 'configures the model with a monthly strategy' do
      test_class.partition_by(:created_at, strategy: :monthly)

      expect(test_class.partitioning_strategy).to be_a(
        Code0::ZeroTrack::Database::Partitioning::Strategy::Monthly
      )
    end

    it 'passes configuration options to the strategy' do
      test_class.partition_by(:created_at, strategy: :daily, retain_for: 90.days, headroom: 14.days)

      strategy = test_class.partitioning_strategy
      expect(strategy.retain_for).to eq(90.days)
      expect(strategy.headroom).to eq(14.days)
    end

    it 'raises ArgumentError for unknown strategy' do
      expect do
        test_class.partition_by(:created_at, strategy: :yearly)
      end.to raise_error(ArgumentError, /Unknown partitioning strategy/)
    end

    it 'raises ArgumentError if table is already partitioned' do
      test_class.partition_by(:created_at, strategy: :daily)

      expect do
        test_class.partition_by(:created_at, strategy: :monthly)
      end.to raise_error(ArgumentError, /already partitioned/)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
