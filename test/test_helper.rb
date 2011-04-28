require 'rubygems'
require 'test/unit'

begin
  require 'shoulda'
rescue LoadError
  puts "Shoulda gem required for running tests:"
  puts "  gem install thoughtbot-shoulda --source http://gems.github.com"
  exit
end

module TestHelper
  @@dir = "test/fixtures/ps-repositories/5.0/"
  @@tmp = "test/tmp"
end

class Test::Unit::TestCase
  include TestHelper
  
  def self.tmp_dir
    Dir.mkdir(@@tmp) unless File.exist?(@@tmp)
    return @@tmp
  end
  
  def tmp_dir
    self.class.tmp_dir
  end
end