require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:'spec:ci')

task :default => :'spec:ci'

def rspec_out_file
  require 'rspec_junit_formatter'
  "-f RspecJunitFormatter -o results.xml"
end

desc "Seed the performance db with millions of events"
task :'db:seed:perf' do
  sh 'time bundle exec ruby spec/benchmark/seed_db.rb'
end

desc "Run the performance benchmarks on the performance db"
task :benchmark do
  sh 'bundle exec ruby spec/benchmark/bench.rb'
end

desc "Run all tests and generate coverage xml"
task :'spec:cov' do
  sh "bundle exec rspec #{rspec_out_file} spec"
end

desc "migrate db"
task :'db:migrate' do
  begin
    sh 'createdb history_store'
  rescue => e
    #we don't care if it exists already, so don't fail
  end
  sh 'psql history_store < db/setup_db_user.sql'
end
