# frozen_string_literal: true

require 'digest'

module Code0
  module ZeroTrack
    module Database
      module MigrationHelpers
        # Helpers for managing polymorphic cleanup triggers.
        #
        # Rails does not enforce referential integrity for polymorphic associations, so deleting a
        # parent record leaves orphaned child rows behind. These helpers install a PostgreSQL trigger
        # that deletes the dependent polymorphic rows whenever a parent row is deleted.
        module PolymorphicTriggerHelpers
          POLYMORPHIC_CLEANUP_FUNCTION_NAME = 'delete_polymorphic_records_v1'
          POLYMORPHIC_CLEANUP_TRANSITION_TABLE = 'old_rows'

          def create_polymorphic_cleanup_trigger(table, parent_table, parent_column, parent_class)
            create_polymorphic_cleanup_function

            trigger_name = polymorphic_cleanup_trigger_name(table, parent_table, parent_column)

            execute(<<~SQL) # rubocop:disable Rails/SquishedSQLHeredocs -- we want to keep the formatting
              CREATE TRIGGER #{quote_table_name(trigger_name)}
              AFTER DELETE ON #{quote_table_name(parent_table)}
              REFERENCING OLD TABLE AS #{POLYMORPHIC_CLEANUP_TRANSITION_TABLE}
              FOR EACH STATEMENT
              EXECUTE FUNCTION #{quote_table_name(POLYMORPHIC_CLEANUP_FUNCTION_NAME)}(
                #{quote(table.to_s)},
                #{quote(parent_column.to_s)},
                #{quote(parent_class.to_s)}
              );
            SQL
          end

          def drop_polymorphic_cleanup_trigger(table, parent_table, parent_column)
            trigger_name = polymorphic_cleanup_trigger_name(table, parent_table, parent_column)

            execute(<<~SQL.squish)
              DROP TRIGGER IF EXISTS #{quote_table_name(trigger_name)} ON #{quote_table_name(parent_table)};
            SQL
          end

          def create_polymorphic_cleanup_function
            execute(<<~SQL) # rubocop:disable Rails/SquishedSQLHeredocs -- we want to keep the formatting
              CREATE OR REPLACE FUNCTION #{quote_table_name(POLYMORPHIC_CLEANUP_FUNCTION_NAME)}()
              RETURNS TRIGGER AS $$
              BEGIN
                EXECUTE format(
                  'DELETE FROM %I WHERE %I = $1 AND %I IN (SELECT id FROM #{POLYMORPHIC_CLEANUP_TRANSITION_TABLE})',
                  TG_ARGV[0],
                  TG_ARGV[1] || '_type',
                  TG_ARGV[1] || '_id'
                ) USING TG_ARGV[2];
                RETURN NULL;
              END;
              $$ LANGUAGE plpgsql;
            SQL
          end

          # This method should only be used to clean up the function once no trigger uses it anymore.
          def drop_polymorphic_cleanup_function
            execute(<<~SQL.squish)
              DROP FUNCTION IF EXISTS #{quote_table_name(POLYMORPHIC_CLEANUP_FUNCTION_NAME)}();
            SQL
          end

          def polymorphic_cleanup_trigger_name(table, parent_table, parent_column)
            identifier = "#{parent_table}_#{parent_column}_#{table}"
            hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)

            "trigger_delete_polymorphic_#{hashed_identifier}"
          end
        end
      end
    end
  end
end
