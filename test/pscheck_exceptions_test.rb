require  File.dirname(__FILE__)+'/test_helper'

class PSCheckExceptionsTest < Test::Unit::TestCase
  # code to get us startup before all tests
  class << self
    
    # runs before all tests
    def startup
      @@dir = "test/fixtures/ps-v4.0.x/"
      @@exception_path = "test/fixtures/known_exceptions.txt"
      @@output = `ruby pscheck.rb -V -x #{@@exception_path} #{@@dir}`
    end
    
    # runs after all tests
    def shutdown; end
    
    def suite
      mysuite = super
      def mysuite.run(*args)
        PSCheckExceptionsTest.startup()
        super
        PSCheckExceptionsTest.shutdown()
      end
      mysuite
    end
  end

  
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
    
  context "pscheck with exception and year 2006" do
    setup do
      @output06 = `ruby pscheck.rb -V-y 2006 -x #{@@exception_path} #{@@dir}`
    end
    
    should "have only skipped documents in 2006" do
      assert_match /skipping AMPH9900011803S001/, @output06
      assert_match /skipping AMPH9900011803S002/, @output06
      assert_match /Signatures packets checked:\s+10/i, @output06
      assert_match /Signatures packets skipped:\s+2/i, @output06
    end
  end

  context "pscheck with exception and year 2007" do
    setup do
      @output07 = `ruby pscheck.rb -V-y 2007 -x #{@@exception_path} #{@@dir}`
    end
    
    should "have only skipped documents in 2007" do
      assert_match /skipping AMPH9900013350S001/, @output07      
      assert_match /Signatures packets checked:\s+0/i, @output07
      assert_match /Signatures packets skipped:\s+1/i, @output07
    end
  end

  context "pscheck with exception file option" do
    setup do
      # before each test
    end

    should "have a list of known exceptions loaded" do
      assert_match /known file exceptions list loaded/i, @@output
      assert_match /AMPH9900013350: Test a document in year 2007/i, @@output
      assert_match /AMPH9900011803: File is corrupted on disk/i, @@output
      assert_match /2 known file exceptions loaded/, @@output
    end
    
    should "have skipped signatures for known exceptions documents" do
      assert_match /skipping AMPH9900011803S001/, @@output
      assert_match /skipping AMPH9900011803S002/, @@output
      assert_match /skipping AMPH9900013350S001/, @@output
    end
    
    should "have the correct sums of checked vs skipped signatures" do
      assert_match /Signatures packets checked:\s+10/i, @@output
      assert_match /Signatures packets skipped:\s+3/i, @@output
    end
  end
  

end