##
## MultiRunner allows us to set the directory context for a suite of tests.
##
## Set the self.dirs in TestHelper and that is used as the context for the
## suite of tests against a PatentSafe repository fixture. Results are
## collected accross suites, displayed at the end of each suite run with
## the total of all tests run to that point.

require  File.dirname(__FILE__)+'/test_helper'

require 'test/unit/ui/console/testrunner'

## Actual runner that knows about TestHelper.dirs
class MultiRunner < Test::Unit::UI::Console::TestRunner

  attr_accessor :result_object

  def self.run(suite, output_level=NORMAL, io=STDOUT)
    results = Test::Unit::TestResult.new # shared results object
    TestCase.dirs.each do |dir|
      puts "Running tests for #{dir}"
      TestCase.dir = dir # set the current directory
      new(suite, output_level, io, results).start
    end
    results
  end

  # allow use of shared results
  def initialize(suite, output_level, io, result)
    @result_object = result
    super(suite, output_level, io)
  end

  private

  # override mediator creation
  def create_mediator(suite)
    return MultiMediator.new(suite, @result_object)
  end
end

# add the runner to the list of runners
Test::Unit::AutoRunner::RUNNERS[:multi] = proc do |r|
  MultiRunner
end


class MultiMediator < Test::Unit::UI::TestRunnerMediator

  attr_accessor :result_object

  # allow use of shared results
  def initialize(suite, result)
    @result_object = result
    super(suite)
  end

  # return the shared results object
  def create_result
    return @result_object
  end
end