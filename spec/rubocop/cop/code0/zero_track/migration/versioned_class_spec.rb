# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RuboCop::Cop::Code0::ZeroTrack::Migration::VersionedClass, type: :rubocop do
  context 'when inside of migration' do
    before do
      allow(cop).to receive_messages(
        in_migration?: true,
        basename: '20231129173717_create_users',
        cop_config: { 'AllowedVersions' => { '2023_11_29_17_37_16..' => 1.0 } }
      )
    end

    it 'registers an offense when the "ActiveRecord::Migration" class is used' do
      expect_offense(<<~CODE)
        class Users < ActiveRecord::Migration[4.2]
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Don't use `ActiveRecord::Migration`. Use `Code0::ZeroTrack::Database::Migration` instead.
          def change
            create_table :users do |t|
              t.string :username, null: false
              t.timestamps_with_timezone null: true
              t.string :password
            end
          end
        end
      CODE

      expect_correction(<<~CODE)
        class Users < Code0::ZeroTrack::Database::Migration[1.0]
          def change
            create_table :users do |t|
              t.string :username, null: false
              t.timestamps_with_timezone null: true
              t.string :password
            end
          end
        end
      CODE
    end

    it 'registers an offense when the wrong version of "Code0::ZeroTrack::Database::Migration" is used' do
      expect_offense(<<~CODE)
        class Users < Code0::ZeroTrack::Database::Migration[1.1]
                                                            ^^^ Don't use version `1.1` of `Code0::ZeroTrack::Database::Migration`. Use version `1.0` instead.
          def change
            create_table :users do |t|
              t.string :username, null: false
              t.timestamps_with_timezone null: true
              t.string :password
            end
          end
        end
      CODE

      expect_correction(<<~CODE)
        class Users < Code0::ZeroTrack::Database::Migration[1.0]
          def change
            create_table :users do |t|
              t.string :username, null: false
              t.timestamps_with_timezone null: true
              t.string :password
            end
          end
        end
      CODE
    end

    it 'registers no offense when correct version is used' do
      expect_no_offenses(<<~CODE)
        class Users < Code0::ZeroTrack::Database::Migration[1.0]
          def change
            create_table :users do |t|
              t.string :username, null: false
              t.timestamps_with_timezone null: true
              t.string :password
            end
          end
        end
      CODE
    end
  end

  context 'when outside of migration' do
    it 'registers no offense' do
      expect_no_offenses(<<~CODE)
        class Users < ActiveRecord::Migration[4.2]
          def change
            create_table :users do |t|
              t.string :username, null: false
              t.timestamps_with_timezone null: true
              t.string :password
            end
          end
        end
      CODE
    end
  end
end
