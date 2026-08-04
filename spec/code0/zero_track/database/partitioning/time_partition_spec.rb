# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/VerifiedDoubles -- AR models require a DB connection for verification.
RSpec.describe Code0::ZeroTrack::Database::Partitioning::TimePartition do
  let(:model) do
    double('Model', table_name: 'events')
  end

  let(:connection) do
    connection = double('Connection')
    allow(connection).to receive(:quote_table_name) { |name| "\"#{name}\"" }
    allow(connection).to receive(:quote) { |value| "'#{value}'" }
    connection
  end

  before do
    allow(Rails.application.config.zero_track.db_partitioning).to receive(:dynamic_partition_schema)
      .and_return('partitions_dynamic')
  end

  describe '.from_sql' do
    it 'parses a standard range partition definition' do
      partition = described_class.from_sql(model, 'events_202301', "FOR VALUES FROM ('2023-01-01') TO ('2023-02-01')")

      expect(partition.model).to eq(model)
      expect(partition.partition_name).to eq('events_202301')
      expect(partition.from).to eq(Date.parse('2023-01-01'))
      expect(partition.to).to eq(Date.parse('2023-02-01'))
    end

    it 'parses a partition with MINVALUE lower bound' do
      partition = described_class.from_sql(model, 'events_initial', "FOR VALUES FROM (MINVALUE) TO ('2023-01-01')")

      expect(partition.from).to be_nil
      expect(partition.to).to eq(Date.parse('2023-01-01'))
    end

    it 'raises ArgumentError for unknown definition format' do
      expect do
        described_class.from_sql(model, 'events_bad', 'SOMETHING UNEXPECTED')
      end.to raise_error(ArgumentError, /Unknown partition definition/)
    end

    it 'raises NotImplementedError for MAXVALUE upper bound' do
      expect do
        described_class.from_sql(model, 'events_max', "FOR VALUES FROM ('2023-01-01') TO (MAXVALUE)")
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#initialize' do
    it 'parses string dates' do
      partition = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')

      expect(partition.from).to eq(Date.new(2023, 1, 1))
      expect(partition.to).to eq(Date.new(2023, 2, 1))
    end

    it 'accepts Date objects' do
      from = Date.new(2023, 1, 1)
      to = Date.new(2023, 2, 1)
      partition = described_class.new(model, from, to, partition_name: 'events_202301')

      expect(partition.from).to eq(from)
      expect(partition.to).to eq(to)
    end

    it 'allows nil from for MINVALUE partitions' do
      partition = described_class.new(model, nil, '2023-02-01', partition_name: 'events_initial')

      expect(partition.from).to be_nil
    end
  end

  describe 'equality and comparison' do
    it 'treats partitions with identical attributes as equal' do
      p1 = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')
      p2 = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')

      expect(p1).to eq(p2)
    end

    it 'treats partitions with any differing attribute as not equal' do
      base = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')
      different_name = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_other')
      different_from = described_class.new(model, '2023-01-15', '2023-02-01', partition_name: 'events_202301')
      different_to = described_class.new(model, '2023-01-01', '2023-03-01', partition_name: 'events_202301')

      expect(base).not_to eq(different_name)
      expect(base).not_to eq(different_from)
      expect(base).not_to eq(different_to)
    end

    it 'can be used in sets for deduplication' do
      p1 = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')
      p2 = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')
      p3 = described_class.new(model, '2023-02-01', '2023-03-01', partition_name: 'events_202302')

      set = Set.new([p1, p2, p3])

      expect(set.size).to eq(2)
    end

    it 'sorts partitions by name within the same model' do
      p1 = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')
      p2 = described_class.new(model, '2023-02-01', '2023-03-01', partition_name: 'events_202302')
      p3 = described_class.new(model, '2023-03-01', '2023-04-01', partition_name: 'events_202303')

      expect([p3, p1, p2].sort).to eq([p1, p2, p3])
    end

    it 'cannot compare partitions across different models' do
      other_model = double('OtherModel', table_name: 'other')
      p1 = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')
      p2 = described_class.new(other_model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')

      expect(p1 <=> p2).to be_nil
    end
  end

  describe 'set arithmetic for partition syncing' do
    it 'computes partitions to create via array subtraction' do
      existing = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')
      desired_new = described_class.new(model, '2023-02-01', '2023-03-01', partition_name: 'events_202302')

      desired = [existing, desired_new]
      current = [existing]

      to_create = desired - current

      expect(to_create).to eq([desired_new])
    end

    it 'computes partitions to detach via array subtraction' do
      kept = described_class.new(model, '2023-02-01', '2023-03-01', partition_name: 'events_202302')
      old = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')

      desired = [kept]
      current = [kept, old]

      to_detach = current - desired

      expect(to_detach).to eq([old])
    end
  end

  describe '#to_create_sql' do
    it 'generates CREATE TABLE IF NOT EXISTS in the dynamic schema' do
      partition = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')

      sql = partition.to_create_sql(connection)

      expect(sql).to eq(
        'CREATE TABLE IF NOT EXISTS "partitions_dynamic"."events_202301" (LIKE "events" INCLUDING ALL)'
      )
    end
  end

  describe '#to_attach_sql' do
    it 'generates ATTACH PARTITION with date range bounds' do
      partition = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')

      sql = partition.to_attach_sql(connection)

      expect(sql).to eq(
        'ALTER TABLE "events" ATTACH PARTITION "partitions_dynamic"."events_202301" ' \
        "FOR VALUES FROM ('2023-01-01') TO ('2023-02-01')"
      )
    end

    it 'uses MINVALUE when from is nil' do
      partition = described_class.new(model, nil, '2023-01-01', partition_name: 'events_initial')

      sql = partition.to_attach_sql(connection)

      expect(sql).to include('FOR VALUES FROM (MINVALUE) TO')
    end
  end

  describe '#to_detach_sql' do
    it 'generates DETACH PARTITION' do
      partition = described_class.new(model, '2023-01-01', '2023-02-01', partition_name: 'events_202301')

      sql = partition.to_detach_sql(connection)

      expect(sql).to eq(
        'ALTER TABLE "events" DETACH PARTITION "partitions_dynamic"."events_202301"'
      )
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
