require 'rubygems'
require 'test/unit'

begin
  require 'shoulda'
rescue LoadError
  puts "Shoulda gem required for running tests:"
  puts "  gem install thoughtbot-shoulda --source http://gems.github.com"
  exit
end

# Our base test class
class TestCase < Test::Unit::TestCase

  # List of patentsafe dirs that will be used for the test, each one is used in
  # in order and the custome MultiRunner sets the self.dir for all the tests to
  # to use in each run.
  def self.dirs
    ["test/fixtures/ps-repositories/5.2/",
     "test/fixtures/ps-repositories/5.1/",
     "test/fixtures/ps-repositories/5.0/",
     "test/fixtures/ps-repositories/4.8/"]
  end

  # accessors for dir
  def self.dir=(dir)
    @@dir = dir
  end

  def self.dir
    @@dir ||= dirs.first
  end

  # accessors for tmp
  def self.tmp=(tmp)
    @@tmp = tmp
  end

  def self.tmp
    @@tmp ||= "test/tmp"
  end

  # instance accessors for dir and tmp
  def dir
    self.class.dir
  end

  def tmp
    self.class.tmp
  end

  def self.tmp_dir
    Dir.mkdir(tmp) unless File.exist?(tmp)
    return tmp
  end

  def tmp_dir
    self.class.tmp_dir
  end

  # callbacks
  def self.before; end

  def self.after; end

  ## Shoehorn some callbacks into TestUnit
  def self.suite
    _suite = super

    # override the run method with a call to callbacks for the give test class
    _suite.instance_eval %Q{
      def run(*args)
        #{self.name}.before if #{self.name}.respond_to?(:before)
        super
        #{self.name}.after if #{self.name}.respond_to?(:after)
      end
    }

    _suite # return the new, modified, suite
  end

  def default_test
    # nothing
  end

end