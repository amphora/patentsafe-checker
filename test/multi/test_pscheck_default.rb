require 'test_helper'

class TestPSCheckDefault < TestCase
  # runs before all tests
  def self.before
    @@output = `ruby pscheck.rb #{dir}`
  end

  # runs after all tests
  def self.after; end

  context "pscheck with default verbosity option" do
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
      assert_match /Signature packets checked:\s+81/i, @@output
    end

    should "have the errors summary" do
      assert_match /-- Errors --/i, @@output
      assert_match /Missing public key:\s+1/i, @@output
      assert_match /Invalid signature texts:\s+1/i, @@output
      assert_match /Invalid content hashes:\s+1/i, @@output
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