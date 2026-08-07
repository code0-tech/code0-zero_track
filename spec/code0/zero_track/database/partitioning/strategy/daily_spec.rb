# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/VerifiedDoubles -- AR models require a DB connection for verification.
RSpec.describe Code0::ZeroTrack::Database::Partitioning::Strategy::Daily do
  include ActiveSupport::Testing::TimeHelpers

  let(:model) { double('Model', table_name: 'events') }

  let(:partitioned_table) { double('PostgresPartitionedTable') }
  let(:postgres_partitions_relation) { double('relation') }

  before do
    allow(Code0::ZeroTrack::Database::Partitioning::PostgresPartitionedTable)
      .to receive(:find_by).with(identifier: 'events').and_return(partitioned_table)
    allow(partitioned_table).to receive(:postgres_partitions).and_return(postgres_partitions_relation)
    allow(postgres_partitions_relation).to receive(:map).and_return([])
  end

  describe '#default_headroom' do
    it 'defaults to 30 days' do
      strategy = described_class.new(model, :created_at)

      expect(strategy.headroom).to eq(30.days)
    end
  end

  describe '#partition_name' do
    it 'generates name with YYYYMMDD suffix' do
      strategy = described_class.new(model, :created_at)

      expect(strategy.partition_name(Date.new(2023, 3, 15))).to eq('events_Y2023M03D15')
    end

    it 'generates zeroed suffix for nil (MINVALUE partition)' do
      strategy = described_class.new(model, :created_at)

      expect(strategy.partition_name(nil)).to eq('events_Y0000M00D00')
    end
  end

  describe '#desired_partitions' do
    context 'with retention enabled' do
      it 'starts from the retention boundary and extends through headroom' do
        travel_to Date.new(2023, 6, 15) do
          strategy = described_class.new(model, :created_at, retain_for: 7.days, headroom: 3.days)

          partitions = strategy.desired_partitions

          expect(partitions.first.from).to eq(Date.new(2023, 6, 8))
          expect(partitions.first.partition_name).to eq('events_Y2023M06D08')
          expect(partitions.last.to).to eq(Date.new(2023, 6, 19)) # current + 1 day + 3 days headroom
          expect(partitions).to all(satisfy { |p| p.to - p.from == 1 })
        end
      end
    end

    context 'without retention' do
      it 'starts from today when no partitions exist yet' do
        travel_to Date.new(2023, 6, 15) do
          strategy = described_class.new(model, :created_at, headroom: 3.days)

          partitions = strategy.desired_partitions

          expect(partitions.first.from).to eq(Date.new(2023, 6, 15))
          expect(partitions.last.to).to eq(Date.new(2023, 6, 19))
        end
      end

      it 'starts from the earliest existing partition when partitions exist' do
        travel_to Date.new(2023, 6, 15) do
          existing = Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
            model, '2023-06-01', '2023-06-02', partition_name: 'events_Y2023M06D01'
          )
          allow(postgres_partitions_relation).to receive(:map).and_return([existing])

          strategy = described_class.new(model, :created_at, headroom: 3.days)

          partitions = strategy.desired_partitions

          expect(partitions.first.from).to eq(Date.new(2023, 6, 1))
        end
      end
    end

    it 'generates one partition per day covering the entire range' do
      travel_to Date.new(2023, 6, 15) do
        strategy = described_class.new(model, :created_at, retain_for: 2.days, headroom: 2.days)

        partitions = strategy.desired_partitions

        # Verify contiguous: each partition's `to` equals the next partition's `from`
        partitions.each_cons(2) do |a, b|
          expect(a.to).to eq(b.from)
        end

        # Verify each partition spans exactly 1 day
        partitions.each do |p|
          expect(p.to - p.from).to eq(1)
        end
      end
    end
  end

  describe '#current_partitions' do
    it 'parses existing partition records into TimePartition objects' do
      partition_record = double('record', name: 'events_Y2023M01D01',
                                          condition: "FOR VALUES FROM ('2023-01-01') TO ('2023-01-02')")

      allow(postgres_partitions_relation).to receive(:map).and_yield(partition_record).and_return(
        [Code0::ZeroTrack::Database::Partitioning::TimePartition.from_sql(
          model, partition_record.name, partition_record.condition
        )]
      )

      strategy = described_class.new(model, :created_at)
      partitions = strategy.current_partitions

      expect(partitions.size).to eq(1)
      expect(partitions.first.partition_name).to eq('events_Y2023M01D01')
      expect(partitions.first.from).to eq(Date.new(2023, 1, 1))
      expect(partitions.first.to).to eq(Date.new(2023, 1, 2))
    end
  end

  describe 'partition syncing logic' do
    it 'identifies new partitions to create and old partitions to detach' do
      travel_to Date.new(2023, 6, 15) do
        # Existing: June 13, 14, 15. Retention: 1 day. Headroom: 2 days.
        existing_partitions = (13..15).map do |day|
          Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
            model, "2023-06-#{day}", "2023-06-#{day + 1}", partition_name: "events_Y2023M06D#{day}"
          )
        end
        allow(postgres_partitions_relation).to receive(:map).and_return(existing_partitions)

        # retain_for 1 day => oldest_active_date = June 14
        # headroom 2 days => max_date = June 15 + 1 + 2 = June 18
        strategy = described_class.new(model, :created_at, retain_for: 1.day, headroom: 2.days)

        # June 13 is before retention boundary (June 14), should be detached
        expect(strategy.partitions_to_detach.map(&:partition_name)).to include('events_Y2023M06D13')
        expect(strategy.partitions_to_detach.map(&:partition_name)).not_to include('events_Y2023M06D14')

        # June 16 and 17 are within headroom but don't exist, should be created
        expect(strategy.partitions_to_create.map(&:partition_name)).to include(
          'events_Y2023M06D16',
          'events_Y2023M06D17'
        )
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
