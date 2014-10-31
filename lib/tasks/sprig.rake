namespace :db do
  namespace :seed do

    desc 'Purge seed files for specified environment'
    task :purge do
      Sprig::Task::PurgeSeeds.new.perform
    end

  end
end
