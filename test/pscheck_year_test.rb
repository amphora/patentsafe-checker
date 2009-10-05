require  File.dirname(__FILE__)+'/test_helper'

class PSCheckYearTest < Test::Unit::TestCase
  # code to get us startup before all tests
  class << self
    
    # runs before all tests
    def startup
      @@dir = "test/fixtures/ps-v4.0.x/"
      @@output06 = `ruby pscheck.rb -V #{@@dir} -y 2006`
      @@output07 = `ruby pscheck.rb -V #{@@dir} -y 2007`
    end
    
    # runs after all tests
    def shutdown; end
    
    def suite
      mysuite = super
      def mysuite.run(*args)
        PSCheckYearTest.startup()
        super
        PSCheckYearTest.shutdown()
      end
      mysuite
    end
  end

  context "pscheck with verbose and year as 2006" do

    should "have error text for known missing public key" do
      assert_match /ERROR:  User public key not found/i, @@output06
    end

    should "have checked twelve signatures" do
      assert_match /Signatures packets checked:\s+12/i, @@output06
    end
    
    should "have the errors summary" do
      assert_match /-- Errors --/i, @@output06
      assert_match /Missing public key:\s+1/i, @@output06
      assert_match /Invalid signature texts:\s+1/i, @@output06
      assert_match /Invalid content hash:\s+1/i, @@output06
      # How to test missing OpenSSL?
      # assert_match /Skipped signatures\*:\s+13/i, @@output
    end
    
    should "have the successful summary" do
      assert_match /-- Successful checks --/i, @@output06
      assert_match /Public keys found:\s+11/i, @@output06
      assert_match /Signature texts:\s+11/i, @@output06
      assert_match /Content hashes:\s+11/i, @@output06
      # Test missing OpenSSL?
      # assert_match /Validated signatures\*:\s+0/i, @@output
    end

  end

  context "pscheck with verbose and year as 2007" do

    should "have checked one signature" do
      assert_match /Signatures packets checked:\s+1/i, @@output07
    end
    
    should "have the successful summary" do
      assert_match /-- Successful checks --/i, @@output07
      assert_match /Public keys found:\s+1/i, @@output07
      assert_match /Signature texts:\s+1/i, @@output07
      assert_match /Content hashes:\s+1/i, @@output07
      # Test missing OpenSSL?
      # assert_match /Validated signatures\*:\s+0/i, @@output
    end
 
  end

  
end