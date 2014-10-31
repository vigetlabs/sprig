require "rake"

shared_context "rake" do
  let(:rake)      { Rake::Application.new }
  let(:task_name) { self.class.top_level_description }
  let(:task_path) { "lib/tasks/sprig" }
  subject         { rake[task_name] }

  def loaded_files_excluding_current_rake_file
    $".reject {|file| file == Rails.root.join("#{task_path}.rake").to_s }
  end

  before do
    Rails.stub(:root).and_return(Pathname.new("#{File.dirname(__FILE__)}/../../.."))
    Rake.application = rake
    Sprig::Railtie.instance.load_tasks
    Rake::Task.define_task(:environment)
  end
end
