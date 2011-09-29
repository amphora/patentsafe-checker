require  File.dirname(__FILE__)+'/test_helper'

class TestPSCheckJsonOut < TestCase
  # runs before all tests
  def self.before
    # c = csv
    # f = output filename
    @@docfile = "#{tmp_dir}/pscheck-docout.json"
    @@docoutput = `ruby pscheck.rb -V -j -d #{@@docfile} #{@@dir}`

    @@sigfile = "#{tmp_dir}/pscheck-sigout.json"
    @@sigoutput = `ruby pscheck.rb -V -j -s #{@@sigfile} #{@@dir}`
  end

  # runs after all tests
  def self.after; end

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
      assert File.exist?(@@docfile)
      assert File.exist?(@@sigfile)
    end

    should "have json output in the file" do
      json = File.open(@@docfile).read
      assert_match /"Document ID":"TEST0100000002"/, json
      assert_match /"Hash":"6ef1f5283a4a7e9772/, json

      json = File.open(@@sigfile).read
      assert_match /"Signature ID":"TEST0100000002S001"/, json
      assert_match /"Value":"ZlaLs3/, json
    end
  end

end