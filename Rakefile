require 'rake'
require 'rake/testtask'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "."
  t.test_files = FileList['test/**/test_*.rb']
  t.verbose = true
end