require 'rubygems'
require 'test/unit'

begin
  require 'shoulda'
rescue LoadError
  puts "Shoulda gem required for running tests:"
  puts "  gem install thoughtbot-shoulda --source http://gems.github.com"
  exit
end