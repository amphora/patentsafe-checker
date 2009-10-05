require  File.dirname(__FILE__)+'/test_helper'

class PSCheckVerboseTest < Test::Unit::TestCase
  # code to get us startup before all tests
  class << self
    
    # runs before all tests
    def startup
      @@dir = "test/fixtures/ps-v4.0.x/"
      @@output = `ruby pscheck.rb -V #{@@dir}`
    end
    
    # runs after all tests
    def shutdown; end
    
    def suite
      mysuite = super
      def mysuite.run(*args)
        PSCheckVerboseTest.startup()
        super
        PSCheckVerboseTest.shutdown()
      end
      mysuite
    end
  end

  context "pscheck with verbose option" do
    setup do
      # before each test
    end

    should "have the start time" do
      assert_match /PatentSafe Check Start/i, @@output
    end
    
    should "have user loading text" do
      # make sure we can test on Windows as well (paths are different)
      assert_match /loading users from test[\\\/]+fixtures[\\\/]+ps-v4.0.x[\\\/]+data[\\\/]+users/i, @@output
    end

    should "have loaded six users" do
      assert_match /6 users loaded/i, @@output
    end

    should "have the correct list of users" do
      assert_match /loaded Installer \[installer\] with 0 keys/i, @@output
      assert_match /loaded A Witness \[witness\] with 0 keys/i, @@output
      assert_match /loaded Kevin Pearcey \(kevinp\) \[kevinp\] with 51 keys/i, @@output
      assert_match /loaded Kevin Pearcey \(p\) \[p\] with 7 keys/i, @@output
      assert_match /loaded User 1 \[user1\] with 0 keys/i, @@output
      assert_match /loaded Stress Test User \[user-00000\] with 0 keys/i, @@output
    end
    
    should "have validating text" do
      assert_match /validating AMPH9900011803S001 at/i, @@output
    end
    
    should "have error text for known invalid document" do
      assert_match /ERROR:  Generated signature is inconsistent with signature packet/i, @@output
      assert_match /ERROR:  Generated document hash is inconsistent with signature packet/i, @@output
    end
    
    should "have error text for known missing public key" do
      assert_match /ERROR:  User public key not found/i, @@output
    end
    
    should "have summary report header" do
      assert_match /PatentSafe Checker Summary Report/i, @@output
    end
    
    should "have checked thirteen signatures" do
      assert_match /Signatures packets checked:\s+13/i, @@output
    end
    
    should "have the errors summary" do
      assert_match /-- Errors --/i, @@output
      assert_match /Corrupt signatures:\s+1/i, @@output
      assert_match /Missing public key:\s+1/i, @@output
      assert_match /Invalid signature texts:\s+1/i, @@output
      assert_match /Invalid content hash:\s+1/i, @@output
      # How to test missing OpenSSL?
      # assert_match /Skipped signatures\*:\s+13/i, @@output
    end
    
    should "have the successful summary" do
      assert_match /-- Successful checks --/i, @@output
      assert_match /Public keys found:\s+12/i, @@output
      assert_match /Signature texts:\s+12/i, @@output
      assert_match /Content hashes:\s+12/i, @@output
      # Test missing OpenSSL?
      # assert_match /Validated signatures\*:\s+0/i, @@output
    end
    
  end
  
  
end