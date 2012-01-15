#!/usr/bin/env ruby 
#
# == Synopsis 
#   Script to scan the PatentSafe document repository checking for
#   document and signature validity. Mainly intended for Amphora's 
#   Hosted PatentSafe servers (and their backup). Produces no output
#   unless there is a problem, so can be run from cron
#
# == Examples
#   
#     ruby check_hosted.rb /base/dir path/suffix
#
#     On Duane run "ruby check_hosted.rb /zones root/export/home/apps/patentsafe" as root
#
# == Usage 
#   check_hosted.rb [options] base_directory path_inside_each_hit
#
#   For help use: ruby check_hosted.rb -h
#
# == Options
#   -h, --help          Displays help message
#
# == Author
#   Amphora Research Systems, Ltd.
#
# == Copyright
#   Copyright (c) 2006-2009 Amphora Research Systems Ltd.
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
# 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
# 
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Things we need to process command line arguments
require 'optparse' 
require 'ostruct'

# The Repository checker 
require "./pscheck"

# For Threading
require 'thread'

# setup our logger STDOUT for now
LOG = Logger.new(STDOUT)
# Only report errors
LOG.level = Logger::ERROR

# This is pretty much copied from the pscheck.rb file
class HostedChecker
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin

    # set defaults
    @options = OpenStruct.new
  end

  # Parse options, check arguments, then process the command
  def run
    if parsed_options? && arguments_valid? 
      # arguments then the pscheck command itself
      process_arguments
      process_command
    else
      output_usage
    end

  end

  protected

  def parsed_options?
    # specify options
    opts = OptionParser.new 
    opts.on('-h', '--help')         { output_help }
    opts.on('-V', '--verbose')             { @options.verbose = true }
    opts.parse!(@arguments) rescue return false
    process_options
    true      
  end

  # Performs post-parse processing on options
  def process_options
    @options.verbose = false if @options.quiet      
  end

  def output_options
    puts "Options:\n"

    @options.marshal_dump.each do |name, val|        
      puts "  #{name} = #{val}"
    end
  end

  # True if required arguments were provided
  def arguments_valid?
    true if @arguments.length == 2 
  end

  # Setup the arguments
  def process_arguments
    @base_path = ARGV[0] if ARGV[0]
    @path_suffix = ARGV[1] if ARGV[1]
  end

  def output_help
    puts version_text
    # RDoc::usage() #exits app
  end

  def output_usage
    # RDoc::usage('usage') # gets usage from comments above
  end

  def output_version
    puts version_text
    puts OptionParser::Version.join('.')
  end

  # This is where the Script actually does something
  # Get all the directories in base_path and see if there's something in path_suffix
  # If there is, run against it
  def process_command 
    # Create an array of the Paths we want to check - global variable so the worker function can see it
    $to_check = Dir.new(@base_path).entries
    # And a Mutex to control access to this so the threads don't trip over each other - global variable so the worker function can see it
    $to_check_mutex = Mutex.new

    # Kick off the threads
    threads = []
    4.times do
      threads << Thread.new {checker_worker}
    end

    puts "Threads runnning:"
    Thread.list.each {|thr| p thr }
    # And wait on them to terminate
    threads.each { |aThread|  aThread.join }

  end   

  def checker_worker
    puts "Checker worker started #{Thread.current.to_s}"
    done = false
    z = ""
    until done do
      # Get exclusive access to the $to_check array
      $to_check_mutex.synchronize do
        # If there's nothing there then we can stop
        if $to_check.size == 0
          done = true
          LOG.info "Nothing else to do so quitting"
        else
          # Get a value to play with and remove from the array
          z = $to_check.delete_at(0)
          LOG.info "Working on #{z}"
        end
      end # End waiting on the Mutex

      puts "Checker worker running on #{z} remaining=#{$to_check.size} thread=#{Thread.current.to_s}"

      # If we have a value then do something (and don't run on invisible directories)
      if not(done) && z[0..0] != "."
        # Run the checker
        repository_directory = "#{@base_path}/#{z}/#{@path_suffix}"
        if File.exists?(repository_directory)
          if File.exists?("#{repository_directory}/disable_checker")
            LOG.info "========================================================================================================================"
            LOG.info "Not Running on #{repository_directory} because disable_checker is present"
            LOG.info "========================================================================================================================"
          else
            LOG.info "========================================================================================================================"
            LOG.info "Running on #{repository_directory}"
            LOG.info "========================================================================================================================"
            begin
              repo = Repository.new(:base_path => repository_directory, :verbose => @options.verbose)
              repo.check
              repository_status = repo.get_repository_data_as_yaml
            rescue
              puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
              puts "Error Running on #{repository_directory}"
              puts "#{$!}"
              puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            end
          end
        else
          LOG.info "**** No directory #{repository_directory}"
        end
      end
    end
  end

  # def process_command      
  #   Dir.new(@base_path).each do | z |
  #     # This doesn't work on Windows but who cares? We only host on Unix
  #     repository_directory = "#{@base_path}/#{z}/#{@path_suffix}"
  #     if File.exists?(repository_directory)
  #       if File.exists?("#{repository_directory}/disable_checker")
  #         LOG.info "========================================================================================================================"
  #         LOG.info "Not Running on #{repository_directory} because disable_checker is present"
  #         LOG.info "========================================================================================================================"
  #       else
  #         LOG.info "========================================================================================================================"
  #         LOG.info "Running on #{repository_directory}"
  #         LOG.info "========================================================================================================================"
  #         repo = Repository.new(:base_path => repository_directory)
  #         repo.check
  #       end
  #     else
  #       LOG.info "**** No directory #{repository_directory}"
  #     end
  # 
  #   end
  # end    

end

# Create and run the application
hosted_checker = HostedChecker.new(ARGV, STDIN)
hosted_checker.run