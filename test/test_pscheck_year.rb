require  File.dirname(__FILE__)+'/test_helper'

class TestPSCheckYear < TestCase
  # runs before all tests
  def self.startup
    @@output09 = `ruby pscheck.rb -V #{@@dir} -y 2009`
    @@output10 = `ruby pscheck.rb -V #{@@dir} -y 2010`
  end

  # runs after all tests
  def self.shutdown; end

  context "pscheck with verbose and year as 2009" do

    should "have error text for known missing public key" do
      assert_match /ERROR:  User public key not found/i, @@output09
    end

    should "have checked seventy one signatures" do
      assert_match /Signature packets checked:\s+71/i, @@output09
    end

    should "have the errors summary" do
      assert_match /-- Errors --/i, @@output09
      assert_match /Missing public key:\s+1/i, @@output09
      assert_match /Invalid signature texts:\s+1/i, @@output09
      assert_match /Invalid content hash:\s+1/i, @@output09
      assert_match /Invalid signatures:\s+1/i, @@output09
      # How to test missing OpenSSL?
      # assert_match /Skipped signatures\*:\s+13/i, @@output
    end

    should "have the successful summary" do
      assert_match /-- Successful checks --/i, @@output09
      assert_match /Public keys found:\s+70/i, @@output09
      assert_match /Signature texts:\s+70/i, @@output09
      assert_match /Content hashes:\s+70/i, @@output09
      # Test missing OpenSSL?
      # assert_match /Validated signatures\*:\s+0/i, @@output
    end

  end

  context "pscheck with verbose and year as 2010" do

    should "have checked ten signatures" do
      assert_match /Signature packets checked:\s+10/i, @@output10
    end

    should "have the successful summary" do
      assert_match /-- Successful checks --/i, @@output10
      assert_match /Public keys found:\s+10/i, @@output10
      assert_match /Signature texts:\s+10/i, @@output10
      assert_match /Content hashes:\s+10/i, @@output10
      # Test missing OpenSSL?
      # assert_match /Validated signatures\*:\s+0/i, @@output
    end

  end


end