# frozen_string_literal: true

module RuboCop
  module Code0
    module ZeroTrack
      module FileHelpers
        def dirname(node)
          File.dirname(filepath(node))
        end

        def basename(node)
          File.basename(filepath(node))
        end

        def filepath(node)
          node.location.expression.source_buffer.name
        end

        def in_migration?(node)
          dirname(node).end_with?('db/migrate')
        end
      end
    end
  end
end
