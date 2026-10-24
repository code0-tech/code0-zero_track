# frozen_string_literal: true

class CreatePartitioningSchema < Code0::ZeroTrack::Database::Migration[1.1]
  def up
    schema = quote_table_name(Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema)
    execute "CREATE SCHEMA #{schema}"
  end

  def down
    schema = quote_table_name(Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema)
    execute "DROP SCHEMA #{schema}"
  end
end
