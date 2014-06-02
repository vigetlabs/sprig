module Sprig
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/reap.rake'
    end
  end
end
