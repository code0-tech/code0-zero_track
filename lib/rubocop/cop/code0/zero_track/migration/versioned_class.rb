# frozen_string_literal: true

require_relative '../../../../code0/zero_track/file_helpers'

module RuboCop
  module Cop
    module Code0
      module ZeroTrack
        module Migration
          class VersionedClass < RuboCop::Cop::Base
            include RuboCop::Code0::ZeroTrack::FileHelpers
            extend AutoCorrector

            MIGRATION_CLASS = 'Code0::ZeroTrack::Database::Migration'

            # rubocop:disable Layout/LineLength
            MSG_WRONG_BASE_CLASS = "Don't use `%<base_class>s`. Use `#{MIGRATION_CLASS}` instead.".freeze
            MSG_WRONG_VERSION = "Don't use version `%<current_version>s` of `#{MIGRATION_CLASS}`. Use version `%<allowed_version>s` instead.".freeze
            # rubocop:enable Layout/LineLength

            def on_class(node)
              return unless in_migration?(node)

              return on_zerotrack_migration(node) if zerotrack_migration?(node)

              add_offense(
                node.parent_class,
                message: format(MSG_WRONG_BASE_CLASS, base_class: superclass(node))
              ) do |corrector|
                corrector.replace(node.parent_class, "#{MIGRATION_CLASS}[#{find_allowed_versions(node).last}]")
              end
            end

            private

            def on_zerotrack_migration(node)
              return if cop_config['AllowedVersions'].nil? # allow all versions if nothing configured
              return if correct_migration_version?(node)

              current_version = get_migration_version(node)
              allowed_version = find_allowed_versions(node).last

              version_node = get_migration_version_node(node)

              add_offense(
                version_node,
                message: format(MSG_WRONG_VERSION, current_version: current_version, allowed_version: allowed_version)
              ) do |corrector|
                corrector.replace(version_node, find_allowed_versions(node).last.to_s)
              end
            end

            def zerotrack_migration?(node)
              superclass(node) == MIGRATION_CLASS
            end

            def superclass(class_node)
              _, *others = class_node.descendants

              others.find { |node| node.const_type? && node.const_name != 'Types' }&.const_name
            end

            def correct_migration_version?(node)
              find_allowed_versions(node).include?(get_migration_version(node))
            end

            def get_migration_version_node(node)
              node.parent_class.arguments[0]
            end

            def get_migration_version(node)
              get_migration_version_node(node).value
            end

            def find_allowed_versions(node)
              migration_version = basename(node).split('_').first.to_i
              allowed_versions.select do |range, _|
                range.include?(migration_version)
              end.values
            end

            def allowed_versions
              cop_config['AllowedVersions'].transform_keys do |range|
                range_ints = range.split('..').map(&:to_i)
                range_ints[0]..range_ints[1]
              end
            end
          end
        end
      end
    end
  end
end
