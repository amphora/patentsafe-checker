require  File.dirname(__FILE__)+'/test_helper'

class TestPSCheckJsonOut < Test::Unit::TestCase
  # code to get us startup before all tests
  class << self
    
    # runs before all tests
    def startup
      # c = csv
      # f = output filename
      @@docfile = "#{tmp_dir}/pscheck-docout.json"
      @@docoutput = `ruby pscheck.rb -V -j -d #{@@docfile} #{@@dir}`
      
      @@sigfile = "#{tmp_dir}/pscheck-sigout.json"
      @@sigoutput = `ruby pscheck.rb -V -j -s #{@@sigfile} #{@@dir}`
    end
    
    # runs after all tests
    def shutdown; end
    
    def suite
      mysuite = super
      def mysuite.run(*args)
        TestPSCheckJsonOut.startup()
        super
        TestPSCheckJsonOut.shutdown()
      end
      mysuite
    end
    
  end
  
  context "pscheck" do
    
    setup do
      @output = `ruby pscheck.rb -h`
    end
    
    should "have the -j option" do
      assert_match /-j/, @output
    end
    
    should "have the -d option" do
      assert_match /-d/, @output
    end
    
    should "have the -s option" do
      assert_match /-s/, @output
    end
  end
  
  context "pscheck with output format as json" do
    
    should "output a file" do
      assert File.exist?(@@sigfile)
    end

    should "have json output in the file" do
      json = File.open(@@sigfile).read
      assert_match /"Signature ID":"TEST0100000002S001"/, json
      assert_match /"Value":"ZlaLs3/, json
    end
  end
  
end