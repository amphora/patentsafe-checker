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
      assert File.exist?(@@sigfile)
    end

    should "have csv output in the file" do
      csv = File.open(@@sigfile).read
      assert_match /"Signature ID","Value"/, csv
    end
  end
  
end