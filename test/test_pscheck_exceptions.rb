require  File.dirname(__FILE__)+'/test_helper'

class TestPSCheckExceptions < TestCase
  # runs before all tests
  def self.before
    @@exception_path = "test/fixtures/known_exceptions.txt"
    @@output = `ruby pscheck.rb -V -x #{@@exception_path} #{@@dir}`
  end

  # runs after all tests
  def self.after; end

  context "pscheck with bad exception file path" do
    setup do
      @badoutput = `ruby pscheck.rb -V -x bad/file/path.txt #{@@dir}`
    end

    should "have the file doesn't exist error" do
      assert_match /Exception list cannot be found at/i, @badoutput
    end
  end

  context "pscheck with unloadable exception file" do
    setup do
      @badoutput = `ruby pscheck.rb -V -x test/fixtures/bad_format_exceptions_file.txt #{@@dir}`
    end

    should "have the file cannot be loaded error" do
      assert_match /could not be loaded/i, @badoutput
    end
  end

  context "pscheck with exception and year 2009" do
    setup do
      @output09 = `ruby pscheck.rb -V-y 2009 -x #{@@exception_path} #{@@dir}`
    end

    should "have only skipped documents in 2009" do
      assert_match /skipping TEST0100000002S001/, @output09
      assert_match /skipping TEST0100000002S002/, @output09
      assert_match /Signature packets checked:\s+69/i, @output09
      assert_match /Signature packets skipped:\s+2/i, @output09
    end
  end

  context "pscheck with exception and year 2010" do
    setup do
      @output10 = `ruby pscheck.rb -V-y 2010 -x #{@@exception_path} #{@@dir}`
    end

    should "have only skipped documents in 2010" do
      assert_match /skipping TEST0100000045S001/, @output10
      assert_match /Signature packets checked:\s+8/i, @output10
      assert_match /Signature packets skipped:\s+2/i, @output10
    end
  end

  context "pscheck with exception file option" do
    setup do
      # before each test
    end

    should "have a list of known exceptions loaded" do
      assert_match /known file exceptions list loaded/i, @@output
      assert_match /TEST0100000045: Test a document in year 2010/i, @@output
      assert_match /TEST0100000002: File is corrupted on disk/i, @@output
      assert_match /2 known file exceptions loaded/, @@output
    end

    should "have skipped signatures for known exceptions documents" do
      assert_match /skipping TEST0100000045S001/, @@output
      assert_match /skipping TEST0100000045S002/, @@output
      assert_match /skipping TEST0100000002S001/, @@output
      assert_match /skipping TEST0100000002S002/, @@output
    end

    should "have the correct sums of checked vs skipped signatures" do
      assert_match /Signature packets checked:\s+77/i, @@output
      assert_match /Signature packets skipped:\s+4/i, @@output
    end
  end


end