# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Logs
      class JsonFormatter < ::Logger::Formatter
        def call(severity, datetime, _progname, message)
          JSON.generate(data(severity, datetime, message)) << "\n"
        end

        def data(severity, datetime, message)
          data = {}
          data[:severity] = severity
          data[:time] = datetime.utc.iso8601(3)

          case message
          when String
            data[:message] = chomp message
          when Hash
            data.merge!(message)
          end

          data.merge!(Code0::ZeroTrack::Context.current.to_h)
        end

        def chomp(message)
          message.chomp! until message.chomp == message

          message.strip
        end

        class NoOpTagStack
          include Singleton

          def push_tags(*)
            []
          end

          def pop_tags(*); end

          def clear; end

          def format_message(message)
            message
          end
        end

        class Tagged < JsonFormatter
          include ActiveSupport::TaggedLogging::Formatter

          def tag_stack
            NoOpTagStack.instance
          end
        end
      end
    end
  end
end
