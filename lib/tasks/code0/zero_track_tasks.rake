# frozen_string_literal: true

namespace :code0 do
  namespace :zero_track do
    namespace :db do
      desc 'This adjusts and cleans db/structure.sql - it runs after db:schema:dump'
      task clean_structure_sql: :environment do |task_name|
        ActiveRecord::Base.configurations
                          .configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env)
                          .each do |db_config|
          structure_file = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(db_config)

          schema = File.read(structure_file)

          File.open(structure_file, 'wb+') do |io|
            Code0::ZeroTrack::Database::SchemaCleaner.new(schema).clean(io)
          end
        end

        # Allow this task to be called multiple times, as happens when running db:migrate:redo
        Rake::Task[task_name].reenable
      end

      if Rails.application.config.zero_track.active_record.schema_cleaner
        # Inform Rake that custom tasks should be run every time rake db:schema:dump is run
        Rake::Task['db:schema:dump'].enhance do
          Rake::Task['code0:zero_track:db:clean_structure_sql'].invoke
        end
        Rake::Task['db:prepare'].enhance do
          Rake::Task['code0:zero_track:db:clean_structure_sql'].invoke
        end
      end
    end
  end
end
