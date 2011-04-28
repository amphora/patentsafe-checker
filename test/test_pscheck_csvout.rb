require  File.dirname(__FILE__)+'/test_helper'

class TestPSCheckCsvOut < Test::Unit::TestCase
  # code to get us startup before all tests
  class << self
    
    # runs before all tests
    def startup
      # c = csv
      # f = output filename
      @@docfile = "#{tmp_dir}/pscheck-docout.csv"
      @@docoutput = `ruby pscheck.rb -V -c -d #{@@docfile} #{@@dir}`
      
      @@sigfile = "#{tmp_dir}/pscheck-sigout.csv"
      @@sigoutput = `ruby pscheck.rb -V -c -s #{@@sigfile} #{@@dir}`
    end
    
    # runs after all tests
    def shutdown; end
    
    def suite
      mysuite = super
      def mysuite.run(*args)
        TestPSCheckCsvOut.startup()
        super
        TestPSCheckCsvOut.shutdown()
      end
      mysuite
    end
    
  end
  
  context "pscheck" do
    
    setup do
      @output = `ruby pscheck.rb -h`
    end
    
    should "have the -c option" do
      assert_match /-c/, @output
    end
    
    should "have the -d option" do
      assert_match /-d/, @output
    end
    
    should "have the -s option" do
      assert_match /-s/, @output
    end
  end
  
  context "pscheck with output format as csv" do
    
    should "output a file" do
      # debug
      puts File.open(@@sigfile).read
      
      assert File.exist?(@@sigfile)
    end
    
  end
  
  # context "pscheck with verbose and year as 2009" do
  # 
  #   should "have error text for known missing public key" do
  #     assert_match /ERROR:  User public key not found/i, @@output09
  #   end
  # 
  #   should "have checked seventy one signatures" do
  #     assert_match /Signatures packets checked:\s+71/i, @@output09
  #   end
  #   
  #   should "have the errors summary" do
  #     assert_match /-- Errors --/i, @@output09
  #     assert_match /Missing public key:\s+1/i, @@output09
  #     assert_match /Invalid signature texts:\s+1/i, @@output09
  #     assert_match /Invalid content hash:\s+1/i, @@output09
  #     assert_match /Invalid signatures:\s+1/i, @@output09
  #     # How to test missing OpenSSL?
  #     # assert_match /Skipped signatures\*:\s+13/i, @@output
  #   end
  #   
  #   should "have the successful summary" do
  #     assert_match /-- Successful checks --/i, @@output09
  #     assert_match /Public keys found:\s+70/i, @@output09
  #     assert_match /Signature texts:\s+70/i, @@output09
  #     assert_match /Content hashes:\s+70/i, @@output09
  #     # Test missing OpenSSL?
  #     # assert_match /Validated signatures\*:\s+0/i, @@output
  #   end
  # 
  # end
  # 
  # context "pscheck with verbose and year as 2010" do
  # 
  #   should "have checked ten signatures" do
  #     assert_match /Signatures packets checked:\s+10/i, @@output10
  #   end
  #   
  #   should "have the successful summary" do
  #     assert_match /-- Successful checks --/i, @@output10
  #     assert_match /Public keys found:\s+10/i, @@output10
  #     assert_match /Signature texts:\s+10/i, @@output10
  #     assert_match /Content hashes:\s+10/i, @@output10
  #     # Test missing OpenSSL?
  #     # assert_match /Validated signatures\*:\s+0/i, @@output
  #   end
  #  
  # end

  
end