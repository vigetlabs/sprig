module Sprig
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/sprig.rake"
    end
  end
end
