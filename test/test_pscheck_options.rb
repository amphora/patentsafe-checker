require 'test_helper'

class TestPSCheckOptions < TestCase

  context "pscheck without options" do
    setup do
      @output = `ruby pscheck.rb`
    end

    should "display the simple usage" do
      assert_match /pscheck.rb \[options\] path_to_repository/, @output
    end
  end

  context "pscheck with help option" do
    setup do
      @output = `ruby pscheck.rb -h`
    end

    should "display the extended usage" do
      assert_match /Displays help message/, @output
    end
  end

  context "pscheck with verbose option" do
    setup do
      @output = `ruby pscheck.rb -V #{@@dir}`
    end

    should "have the start time" do
      assert_match /PatentSafe Check Start/, @output
    end
  end


end