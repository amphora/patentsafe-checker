require 'rake'
require 'rake/testtask'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "."
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end