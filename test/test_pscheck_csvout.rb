require 'test_helper'

class TestPSCheckCsvOut < TestCase
  # runs before all tests
  def self.before
    # c = csv
    # f = output filename
    @@docfile = "#{tmp_dir}/pscheck-docout.csv"
    @@docoutput = `ruby pscheck.rb -V -c -d #{@@docfile} #{dir}`

    @@sigfile = "#{tmp_dir}/pscheck-sigout.csv"
    @@sigoutput = `ruby pscheck.rb -V -c -s #{@@sigfile} #{dir}`
  end

  # runs after all tests
  def self.after; end

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
      assert File.exist?(@@docfile)
      assert File.exist?(@@sigfile)
    end

    should "have csv output in the file" do
      csv = File.open(@@docfile).read
      assert_match /"Document ID","Hash"/, csv

      csv = File.open(@@sigfile).read
      assert_match /"Signature ID","Value"/, csv
    end
  end

end