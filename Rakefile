require 'rake'
require 'rake/testtask'

task :default => :test

desc "Run all tests"
task :test => ['test:multi', 'test:std']

namespace :test do

  desc "Run all tests"
  task :all => :test

  Rake::TestTask.new :std do |t|
    t.libs << "." << "test"
    t.test_files = FileList['test/test_*.rb']
    t.verbose = true
  end

  Rake::TestTask.new :multi do |t|
    t.libs << "." << "test"
    t.ruby_opts=['-rmulti_runner']
    t.test_files = FileList['test/multi/test_*.rb']
    t.verbose = true
    t.options = "--runner=multi"
  end

end