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
  end
end
