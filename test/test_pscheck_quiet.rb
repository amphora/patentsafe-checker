require  File.dirname(__FILE__)+'/test_helper'

class TestPSCheckQuiet < Test::Unit::TestCase
  # code to get us startup before all tests
  class << self
    
    # runs before all tests
    def startup
      @@output = `ruby pscheck.rb -q #{@@dir}`
    end
    
    # runs after all tests
    def shutdown; end
    
    def suite
      mysuite = super
      def mysuite.run(*args)
        TestPSCheckQuiet.startup()
        super
        TestPSCheckQuiet.shutdown()
      end
      mysuite
    end
  end

  context "pscheck with quiet option" do
    setup do
      # before each test
    end

    should "not have the start time" do
      assert_no_match /PatentSafe Check Start/i, @@output
    end
    
    should "not have validating text" do
      assert_no_match /validating TEST0100000003S001 at/i, @@output
    end
    
    should "not have the checked counts" do
      assert_no_match /Document packets checked:\s+53/i, @@output
      assert_no_match /Signature packets checked:\s+81/i, @@output
    end
    
    should "not have the errors summary" do
      assert_no_match /-- Errors --/i, @@output
      # How to test missing OpenSSL?
      # assert_match /Skipped signatures\*:\s+13/i, @@output
    end
    
    should "not have the successful summary" do
      assert_no_match /-- Successful checks --/i, @@output
      # Test missing OpenSSL?
      # assert_match /Validated signatures\*:\s+0/i, @@output
    end
    
  end
  
  
end