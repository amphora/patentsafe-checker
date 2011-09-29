require 'rake'
require 'rake/testtask'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "." << "test"
  t.ruby_opts=['-rmulti_runner']
  t.test_files = FileList['test/**/test_*.rb']
  t.verbose = true
  t.options = "--runner=multi"
end