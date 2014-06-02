namespace :db do
  namespace :seed do
    desc 'Create Sprig seed files from database records'
    task :reap => :environment do
      Rails.application.eager_load!
      Sprig::Harvest.reap(ENV)
    end
  end
end
