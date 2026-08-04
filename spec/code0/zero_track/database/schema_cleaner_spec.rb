# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Code0::ZeroTrack::Database::SchemaCleaner do
  before do
    allow(Rails.application.config.zero_track.db_partitioning).to receive(:dynamic_partition_schema)
      .and_return('partitions_dynamic')
  end

  describe '#clean' do
    subject(:clean) do
      output = StringIO.new
      described_class.new(input).clean(output)
      output.string
    end

    context 'when removing general noise' do
      let(:input) do
        <<~SQL
          SET statement_timeout = 0;
          SET lock_timeout = 0;

          SELECT pg_catalog.set_config('search_path', '', false);

          -- This is a comment

          COMMENT ON EXTENSION "plpgsql" IS 'PL/pgSQL procedural language';

          CREATE TABLE users (
              id bigint NOT NULL,
              name text NOT NULL
          );
        SQL
      end

      it 'removes SET statements' do
        expect(clean).not_to include('SET ')
      end

      it 'removes SELECT pg_catalog' do
        expect(clean).not_to include('pg_catalog')
      end

      it 'removes comments' do
        expect(clean).not_to include('-- This is a comment')
      end

      it 'removes COMMENT ON EXTENSION' do
        expect(clean).not_to include('COMMENT ON EXTENSION')
      end

      it 'preserves table definitions' do
        expect(clean).to include('CREATE TABLE users')
      end
    end

    context 'when removing public schema qualifications' do
      let(:input) do
        <<~SQL # rubocop:disable Rails/SquishedSQLHeredocs -- this should match how a structure.sql is generated
          CREATE TABLE public.users (
              id bigint NOT NULL
          );

          CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA public;
        SQL
      end

      it 'removes public. prefix from identifiers' do
        expect(clean).to include('CREATE TABLE users')
        expect(clean).not_to include('public.users')
      end

      it 'removes WITH SCHEMA public from extensions' do
        expect(clean).to include('CREATE EXTENSION IF NOT EXISTS plpgsql;')
        expect(clean).not_to include('WITH SCHEMA public')
      end
    end

    context 'when removing dynamic partition objects' do
      let(:input) do
        <<~SQL # rubocop:disable Rails/SquishedSQLHeredocs -- this should match how a structure.sql is generated
          CREATE TABLE p_audit_events (
              id bigint NOT NULL,
              author_id bigint NOT NULL,
              created_at timestamp with time zone NOT NULL
          )
          PARTITION BY RANGE (created_at);

          CREATE TABLE partitions_dynamic.p_audit_events_202607 (
              id bigint NOT NULL,
              author_id bigint NOT NULL,
              created_at timestamp with time zone NOT NULL
          );

          CREATE TABLE partitions_dynamic.p_audit_events_202608 (
              id bigint NOT NULL,
              author_id bigint NOT NULL,
              created_at timestamp with time zone NOT NULL
          );

          CREATE TABLE users (
              id bigint NOT NULL,
              name text NOT NULL
          );

          ALTER TABLE ONLY p_audit_events ATTACH PARTITION partitions_dynamic.p_audit_events_202607 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00');

          ALTER TABLE ONLY p_audit_events ATTACH PARTITION partitions_dynamic.p_audit_events_202608 FOR VALUES FROM ('2026-08-01 00:00:00+00') TO ('2026-09-01 00:00:00+00');

          ALTER TABLE ONLY p_audit_events
              ADD CONSTRAINT p_audit_events_pkey PRIMARY KEY (id, created_at);

          ALTER TABLE ONLY partitions_dynamic.p_audit_events_202607
              ADD CONSTRAINT p_audit_events_202607_pkey PRIMARY KEY (id, created_at);

          ALTER TABLE ONLY partitions_dynamic.p_audit_events_202608
              ADD CONSTRAINT p_audit_events_202608_pkey PRIMARY KEY (id, created_at);

          ALTER TABLE ONLY users
              ADD CONSTRAINT users_pkey PRIMARY KEY (id);

          CREATE INDEX index_p_audit_events_on_author_id ON ONLY p_audit_events USING btree (author_id);

          CREATE INDEX p_audit_events_202607_author_id_idx ON partitions_dynamic.p_audit_events_202607 USING btree (author_id);

          CREATE INDEX p_audit_events_202608_author_id_idx ON partitions_dynamic.p_audit_events_202608 USING btree (author_id);

          CREATE UNIQUE INDEX index_users_on_name ON users USING btree (name);

          ALTER INDEX index_p_audit_events_on_author_id ATTACH PARTITION partitions_dynamic.p_audit_events_202607_author_id_idx;

          ALTER INDEX p_audit_events_pkey ATTACH PARTITION partitions_dynamic.p_audit_events_202607_pkey;

          ALTER INDEX index_p_audit_events_on_author_id ATTACH PARTITION partitions_dynamic.p_audit_events_202608_author_id_idx;

          ALTER INDEX p_audit_events_pkey ATTACH PARTITION partitions_dynamic.p_audit_events_202608_pkey;

          ALTER TABLE p_audit_events
              ADD CONSTRAINT fk_rails_9c5a4c4493 FOREIGN KEY (author_id) REFERENCES users(id);
        SQL
      end

      it 'removes CREATE TABLE for dynamic partitions' do
        expect(clean).not_to include('partitions_dynamic.p_audit_events_202607')
        expect(clean).not_to include('partitions_dynamic.p_audit_events_202608')
      end

      it 'preserves the parent partitioned table' do
        expect(clean).to include('CREATE TABLE p_audit_events')
        expect(clean).to include('PARTITION BY RANGE (created_at)')
      end

      it 'preserves unrelated tables' do
        expect(clean).to include('CREATE TABLE users')
      end

      it 'removes ATTACH PARTITION statements for dynamic partitions' do
        expect(clean).not_to include('ATTACH PARTITION partitions_dynamic.')
      end

      it 'removes ALTER TABLE ONLY for dynamic partition constraints' do
        expect(clean).not_to include('p_audit_events_202607_pkey')
        expect(clean).not_to include('p_audit_events_202608_pkey')
      end

      it 'preserves constraints on the parent table' do
        expect(clean).to include('p_audit_events_pkey PRIMARY KEY (id, created_at)')
      end

      it 'preserves constraints on unrelated tables' do
        expect(clean).to include('users_pkey PRIMARY KEY (id)')
      end

      it 'removes CREATE INDEX on dynamic partitions' do
        expect(clean).not_to include('p_audit_events_202607_author_id_idx')
        expect(clean).not_to include('p_audit_events_202608_author_id_idx')
      end

      it 'preserves indexes on the parent table' do
        expect(clean).to include('CREATE INDEX index_p_audit_events_on_author_id ON ONLY p_audit_events')
      end

      it 'preserves indexes on unrelated tables' do
        expect(clean).to include('CREATE UNIQUE INDEX index_users_on_name ON users')
      end

      it 'removes ALTER INDEX ... ATTACH PARTITION for dynamic partitions' do
        expect(clean).not_to include('ALTER INDEX index_p_audit_events_on_author_id ATTACH PARTITION')
        expect(clean).not_to include('ALTER INDEX p_audit_events_pkey ATTACH PARTITION')
      end

      it 'preserves foreign keys on the parent table' do
        expect(clean).to include('fk_rails_9c5a4c4493 FOREIGN KEY (author_id) REFERENCES users(id)')
      end
    end

    context 'with a custom dynamic partition schema name' do
      before do
        allow(Rails.application.config.zero_track.db_partitioning).to receive(:dynamic_partition_schema)
          .and_return('custom_partitions')
      end

      let(:input) do
        <<~SQL # rubocop:disable Rails/SquishedSQLHeredocs -- this should match how a structure.sql is generated
          CREATE TABLE custom_partitions.events_202607 (
              id bigint NOT NULL
          );

          CREATE TABLE partitions_dynamic.unrelated_202607 (
              id bigint NOT NULL
          );
        SQL
      end

      it 'removes partitions from the configured schema' do
        expect(clean).not_to include('custom_partitions.events_202607')
      end

      it 'does not remove partitions from other schemas' do
        expect(clean).to include('partitions_dynamic.unrelated_202607')
      end
    end
  end
end
