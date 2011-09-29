require 'test_helper'

class TestPSCheckBadReppo < TestCase
  # runs before all tests
  def self.before
    @@bad_repo = "test/fixtures/ps-repositories/5.0-bad/"
    @@bad_doc_path = "#{@@bad_repo}data/2010/01/14/TEST0100000049/submitted.pdf"
    @@output = `ruby pscheck.rb #{@@bad_repo}`
  end

  # runs after all tests
  def self.after; end

  context "pscheck with verbose option" do
    setup do
      # before each test
    end

    should "have missing document errors" do
      assert_match /Document content expected at #{@@bad_doc_path}/i, @@output
      assert_match /Cannot validate document hash for missing document at #{@@bad_doc_path}/i, @@output

      assert_match /-- Errors --/i, @@output
      assert_match /Missing documents:\s+1/i, @@output
    end

  end

end