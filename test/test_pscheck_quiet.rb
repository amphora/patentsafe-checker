require  File.dirname(__FILE__)+'/test_helper'

class TestPSCheckQuiet < TestCase
  # runs before all tests
  def self.startup
    @@output = `ruby pscheck.rb -q #{@@dir}`
  end

  # runs after all tests
  def self.shutdown; end

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