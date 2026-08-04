# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/VerifiedDoubles -- AR models require a DB connection for verification.
RSpec.describe Code0::ZeroTrack::Database::Partitioning::Strategy::Monthly do
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
    it 'defaults to 6 months' do
      strategy = described_class.new(model, :created_at)

      expect(strategy.headroom).to eq(6.months)
    end
  end

  describe '#partition_name' do
    it 'generates name with YYYYMM suffix' do
      strategy = described_class.new(model, :created_at)

      expect(strategy.partition_name(Date.new(2023, 3, 15))).to eq('events_Y2023M03')
    end

    it 'generates zeroed suffix for nil (MINVALUE partition)' do
      strategy = described_class.new(model, :created_at)

      expect(strategy.partition_name(nil)).to eq('events_Y0000M00')
    end
  end

  describe '#desired_partitions' do
    context 'with retention enabled' do
      it 'starts from the retention boundary at beginning of month' do
        travel_to Date.new(2023, 6, 15) do
          strategy = described_class.new(model, :created_at, retain_for: 3.months, headroom: 2.months)

          partitions = strategy.desired_partitions

          # 3 months ago from June 15 = March 15, beginning_of_month = March 1
          expect(partitions.first.from).to eq(Date.new(2023, 3, 1))
          expect(partitions.first.partition_name).to eq('events_Y2023M03')
          # end_of_month of June = June 30, + 2 months = August 30
          expect(partitions.last.to).to be >= Date.new(2023, 8, 1)
        end
      end
    end

    context 'without retention' do
      it 'starts from beginning of current month when no partitions exist' do
        travel_to Date.new(2023, 6, 15) do
          strategy = described_class.new(model, :created_at, headroom: 2.months)

          partitions = strategy.desired_partitions

          expect(partitions.first.from).to eq(Date.new(2023, 6, 1))
        end
      end

      it 'starts from the earliest existing partition month when partitions exist' do
        travel_to Date.new(2023, 6, 15) do
          existing = Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
            model, '2023-03-01', '2023-04-01', partition_name: 'events_Y2023M03'
          )
          allow(postgres_partitions_relation).to receive(:map).and_return([existing])

          strategy = described_class.new(model, :created_at, headroom: 2.months)

          partitions = strategy.desired_partitions

          expect(partitions.first.from).to eq(Date.new(2023, 3, 1))
        end
      end
    end

    it 'generates contiguous monthly partitions' do
      travel_to Date.new(2023, 6, 15) do
        strategy = described_class.new(model, :created_at, retain_for: 2.months, headroom: 2.months)

        partitions = strategy.desired_partitions

        # Verify contiguous: each partition's `to` equals the next partition's `from`
        partitions.each_cons(2) do |a, b|
          expect(a.to).to eq(b.from)
        end

        # Verify each partition starts on the 1st
        partitions.each do |p|
          expect(p.from.day).to eq(1)
          expect(p.to.day).to eq(1)
        end
      end
    end
  end

  describe '#current_partitions' do
    it 'parses existing partition records into TimePartition objects' do
      partition_record = double('record', name: 'events_Y2023M01',
                                          condition: "FOR VALUES FROM ('2023-01-01') TO ('2023-02-01')")

      allow(postgres_partitions_relation).to receive(:map).and_yield(partition_record).and_return(
        [Code0::ZeroTrack::Database::Partitioning::TimePartition.from_sql(
          model, partition_record.name, partition_record.condition
        )]
      )

      strategy = described_class.new(model, :created_at)
      partitions = strategy.current_partitions

      expect(partitions.size).to eq(1)
      expect(partitions.first.partition_name).to eq('events_Y2023M01')
      expect(partitions.first.from).to eq(Date.new(2023, 1, 1))
      expect(partitions.first.to).to eq(Date.new(2023, 2, 1))
    end
  end

  describe 'partition syncing logic' do
    it 'identifies new partitions to create and old partitions to detach' do
      travel_to Date.new(2023, 6, 15) do
        # Existing: March, April, May, June
        existing_partitions = (3..6).map do |month|
          from = Date.new(2023, month, 1)
          to = from.next_month
          Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
            model, from, to, partition_name: "events_Y2023M#{format('%02d', month)}"
          )
        end
        allow(postgres_partitions_relation).to receive(:map).and_return(existing_partitions)

        # retain_for: 2 months (from June 15, 2 months ago = April 15, beginning_of_month = April 1)
        # headroom: 2 months (end_of_month June = June 30, + 2 months = August 30)
        strategy = described_class.new(model, :created_at, retain_for: 2.months, headroom: 2.months)

        # March is before retention boundary (April 1), should be detached
        expect(strategy.partitions_to_detach.map(&:partition_name)).to include('events_Y2023M03')
        expect(strategy.partitions_to_detach.map(&:partition_name)).not_to include('events_Y2023M04')

        # July and August don't exist yet but are within headroom
        expect(strategy.partitions_to_create.map(&:partition_name)).to include('events_Y2023M07', 'events_Y2023M08')
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
