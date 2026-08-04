# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/VerifiedDoubles -- AR models require a DB connection for verification.
RSpec.describe Code0::ZeroTrack::Database::Partitioning::PartitionManager do
  include ActiveSupport::Testing::TimeHelpers

  let(:model) do
    model = double('Model', table_name: 'events') # rubocop:disable RSpec/VerifiedDoubles
    allow(model).to receive(:try).with(:partitioning_strategy).and_return(partitioning_strategy)
    allow(model).to receive(:partitioning_strategy).and_return(partitioning_strategy)
    allow(model).to receive(:with_connection).and_yield(connection)
    model
  end

  let(:partitioning_strategy) { double('Strategy') }

  let(:connection) do
    connection = double('Connection')
    allow(connection).to receive(:execute)
    allow(connection).to receive(:transaction).and_yield
    allow(connection).to receive(:quote_table_name) { |name| "\"#{name}\"" }
    allow(connection).to receive(:quote) { |value| "'#{value}'" }
    connection
  end

  let(:rails_logger) { instance_double(ActiveSupport::Logger, info: nil, debug: nil, warn: nil, error: nil) }

  before do
    allow(Rails).to receive(:logger).and_return(rails_logger)
    allow(Rails.application.config.zero_track.db_partitioning).to receive(:dynamic_partition_schema)
      .and_return('partitions_dynamic')
  end

  describe '#initialize' do
    it 'raises ArgumentError if model has no partitioning_strategy' do
      model_without_strategy = double('Model', table_name: 'bad')
      allow(model_without_strategy).to receive(:try).with(:partitioning_strategy).and_return(nil)

      expect do
        described_class.new(model_without_strategy)
      end.to raise_error(ArgumentError, /not configured for partitioning/)
    end
  end

  describe '#sync_partitions' do
    it 'creates, detaches, and drops partitions' do
      partition_to_create = Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
        model, '2023-03-01', '2023-04-01', partition_name: 'events_202303'
      )
      partition_to_detach = Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
        model, '2022-01-01', '2022-02-01', partition_name: 'events_202201'
      )
      partition_to_drop = double('DetachedPartition', schema: 'partitions_dynamic',
                                                      name: 'events_202101',
                                                      parent_identifier: 'events')

      allow(partitioning_strategy).to receive_messages(
        partitions_to_create: [partition_to_create],
        partitions_to_detach: [partition_to_detach],
        partitions_to_drop: [partition_to_drop]
      )

      manager = described_class.new(model)
      manager.sync_partitions!

      executed_sql = []
      expect(connection).to have_received(:execute).at_least(:once) do |sql|
        executed_sql << sql
      end

      expect(executed_sql).to include(a_string_matching(/CREATE TABLE IF NOT EXISTS.*events_202303/))
      expect(executed_sql).to include(a_string_matching(/ATTACH PARTITION.*events_202303/))
      expect(executed_sql).to include(a_string_matching(/DETACH PARTITION.*events_202201/))
      expect(executed_sql).to include(a_string_matching(/DROP TABLE.*events_202101/))
    end
  end

  describe '#create_partitions' do
    it 'executes CREATE TABLE and ATTACH PARTITION for each partition' do
      partition = Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
        model, '2023-01-01', '2023-02-01', partition_name: 'events_202301'
      )
      allow(partitioning_strategy).to receive(:partitions_to_create).and_return([partition])

      manager = described_class.new(model)
      manager.create_partitions!

      expect(connection).to have_received(:execute).with(
        a_string_matching(
          /CREATE TABLE IF NOT EXISTS "partitions_dynamic"."events_202301".*LIKE "events" INCLUDING ALL/
        )
      )
      expect(connection).to have_received(:execute).with(
        a_string_matching(
          /ALTER TABLE "events" ATTACH PARTITION "partitions_dynamic"."events_202301".*FOR VALUES FROM/
        )
      )
    end

    it 'creates multiple partitions in a single transaction' do
      partitions = [
        Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
          model, '2023-01-01', '2023-02-01', partition_name: 'events_202301'
        ),
        Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
          model, '2023-02-01', '2023-03-01', partition_name: 'events_202302'
        )
      ]
      allow(partitioning_strategy).to receive(:partitions_to_create).and_return(partitions)

      manager = described_class.new(model)
      manager.create_partitions!

      expect(connection).to have_received(:transaction).once
      expect(connection).to have_received(:execute).with(a_string_matching(/events_202301/)).twice
      expect(connection).to have_received(:execute).with(a_string_matching(/events_202302/)).twice
    end

    it 'does nothing when there are no partitions to create' do
      allow(partitioning_strategy).to receive(:partitions_to_create).and_return([])

      manager = described_class.new(model)
      manager.create_partitions!

      expect(connection).not_to have_received(:execute).with(a_string_matching(/CREATE TABLE/))
    end
  end

  describe '#detach_partitions' do
    it 'executes DETACH PARTITION and records metadata in a comment' do
      freeze_time do
        partition = Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
          model, '2023-01-01', '2023-02-01', partition_name: 'events_202301'
        )
        allow(partitioning_strategy).to receive(:partitions_to_detach).and_return([partition])

        manager = described_class.new(model)
        manager.detach_partitions!

        expect(connection).to have_received(:execute).with(
          a_string_matching(/ALTER TABLE "events" DETACH PARTITION "partitions_dynamic"."events_202301"/)
        )
        expect(connection).to have_received(:execute).with(
          a_string_matching(/COMMENT ON TABLE "partitions_dynamic"."events_202301"/)
        )
      end
    end

    it 'includes detached_at timestamp in the comment' do
      freeze_time do
        partition = Code0::ZeroTrack::Database::Partitioning::TimePartition.new(
          model, '2023-01-01', '2023-02-01', partition_name: 'events_202301'
        )
        allow(partitioning_strategy).to receive(:partitions_to_detach).and_return([partition])

        manager = described_class.new(model)
        manager.detach_partitions!

        expect(connection).to have_received(:execute).with(
          a_string_matching(/COMMENT.*#{Regexp.escape(Time.current.iso8601)}/)
        )
      end
    end

    it 'does nothing when there are no partitions to detach' do
      allow(partitioning_strategy).to receive(:partitions_to_detach).and_return([])

      manager = described_class.new(model)
      manager.detach_partitions!

      expect(connection).not_to have_received(:execute).with(a_string_matching(/DETACH/))
    end
  end

  describe '#drop_partitions' do
    it 'executes DROP TABLE for each detached partition' do
      detached_partition = double('DetachedPartition', schema: 'partitions_dynamic',
                                                       name: 'events_202301',
                                                       parent_identifier: 'events')
      allow(partitioning_strategy).to receive(:partitions_to_drop).and_return([detached_partition])

      manager = described_class.new(model)
      manager.drop_partitions!

      expect(connection).to have_received(:execute).with(
        a_string_matching(/DROP TABLE "partitions_dynamic"."events_202301"/)
      )
    end

    it 'does nothing when there are no partitions to drop' do
      allow(partitioning_strategy).to receive(:partitions_to_drop).and_return([])

      manager = described_class.new(model)
      manager.drop_partitions!

      expect(connection).not_to have_received(:execute).with(a_string_matching(/DROP TABLE/))
    end
  end

  describe '.sync_all_partitions' do
    it 'syncs partitions for each registered model' do
      models = [model]
      allow(described_class).to receive(:models).and_return(models)
      allow(partitioning_strategy).to receive_messages(
        partitions_to_create: [],
        partitions_to_detach: [],
        partitions_to_drop: []
      )

      described_class.sync_all_partitions!

      expect(partitioning_strategy).to have_received(:partitions_to_create)
      expect(partitioning_strategy).to have_received(:partitions_to_detach)
      expect(partitioning_strategy).to have_received(:partitions_to_drop)
    end
  end

  describe 'locking' do
    it 'acquires an advisory lock before executing partition operations' do
      allow(partitioning_strategy).to receive(:partitions_to_create).and_return([])

      manager = described_class.new(model)

      call_order = []
      allow(connection).to receive(:execute) do |sql|
        call_order << sql
      end

      manager.create_partitions!

      expect(call_order.first).to match(/pg_advisory_xact_lock/)
    end

    it 'uses a lock key scoped to the table name' do
      allow(partitioning_strategy).to receive(:partitions_to_create).and_return([])

      other_model = double('OtherModel', table_name: 'other_events')
      allow(other_model).to receive(:try).with(:partitioning_strategy).and_return(partitioning_strategy)
      allow(other_model).to receive(:partitioning_strategy).and_return(partitioning_strategy)
      allow(other_model).to receive(:with_connection).and_yield(connection)

      lock_keys = []
      allow(connection).to receive(:execute) do |sql|
        lock_keys << sql.match(/pg_advisory_xact_lock\((\d+)\)/)[1] if sql.match?(/pg_advisory_xact_lock/)
      end

      described_class.new(model).create_partitions!
      described_class.new(other_model).create_partitions!

      expect(lock_keys.size).to eq(2)
      expect(lock_keys[0]).not_to eq(lock_keys[1])
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
