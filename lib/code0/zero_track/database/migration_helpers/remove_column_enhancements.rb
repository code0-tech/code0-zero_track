# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module MigrationHelpers
        module RemoveColumnEnhancements
          def remove_column(table_name, column_name, type = nil, **kwargs)
            if type == :text
              limit = kwargs.delete(:limit)
              unique = kwargs.delete(:unique)

              if limit
                quoted_column_name = quote_column_name(column_name)
                name = text_limit_name(table_name, column_name)
                definition = "char_length(#{quoted_column_name}) <= #{limit}"

                remove_check_constraint(table_name, definition, name: name)
              end

              if unique.is_a?(Hash)
                quoted_column_name ||= quote_column_name(column_name)
                index_column = column_name
                unique[:where] = "#{column_name} IS NOT NULL" if unique.delete(:allow_nil_duplicate)
                index_column = "LOWER(#{quoted_column_name})" if unique.delete(:case_insensitive)

                remove_index table_name, index_column, unique: true, **unique
              elsif unique
                remove_index table_name, column_name, unique: unique
              end
            end

            super
          end
        end
      end
    end
  end
end
