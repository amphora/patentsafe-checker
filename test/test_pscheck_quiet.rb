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
    
    should "have checked eighty one signatures" do
      assert_match /Signatures packets checked:\s+81/i, @@output
    end
    
    should "have the errors summary" do
      assert_match /-- Errors --/i, @@output
      assert_match /Missing public key:\s+1/i, @@output
      assert_match /Invalid signature texts:\s+1/i, @@output
      assert_match /Invalid content hash:\s+1/i, @@output
      assert_match /Invalid signatures:\s+1/i, @@output
      # How to test missing OpenSSL?
      # assert_match /Skipped signatures\*:\s+13/i, @@output
    end
    
    should "have the successful summary" do
      assert_match /-- Successful checks --/i, @@output
      assert_match /Public keys found:\s+80/i, @@output
      assert_match /Signature texts:\s+80/i, @@output
      assert_match /Content hashes:\s+80/i, @@output
      # Test missing OpenSSL?
      # assert_match /Validated signatures\*:\s+0/i, @@output
    end
    
  end
  
  
end