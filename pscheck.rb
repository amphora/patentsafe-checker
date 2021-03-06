#!/usr/bin/env ruby
#
# == Synopsis
#   Script to scan the PatentSafe document repository checking for
#   document and signature validity.
#
# == Examples
#
#     ruby pscheck.rb
#
#   Other examples:
#     ruby pscheck.rb -q /path/to/repository
#     ruby pscheck.rb --verbose /path/to/repository
#     ruby pscheck.rb -y 2007 -v /path/to/repository
#
# == Usage
#   pscheck.rb [options] path_to_repository
#
#   For help use: ruby pscheck.rb -h
#
# == Options
#   -h, --help          Displays help message
#   -v, --version       Display the version, then exit
#   -q, --quiet         Output as little as possible, overrides verbose
#   -V, --verbose       Verbose output
#   -s, --skip          Skip document and signature validation
#   -y, --year          Only scan year given
#   -c, --csv           Output docfile/sigfile in csv format
#   -j, --json          Output docfile/sigfile in json format
#   -x, --exceptions    Path to file with a list of known exceptions
#
# == Exceptions File
#
#  Files listed in this file are skipped during validation. Known exception
#  file format - each file listed on a new line with a space after the :, e.g.
#  `DOCID: Explanation/comment/note`. Here is an example.
#
#     AMPH9900011803: This file is corrupt because the hard-drive crashed
#     AMPH9900011804: This file is known to be corrupt 20 Apr 07
#
# == Summary report definitions
#
#  The checker generates a summary report at the end of process. This report
#  contains information on what is checked and the results of those checks.
#
#  Some definitions may help understand what these calculations mean:
#
#  **Document packet**: an xml file that contains information about the
#  submitted document. Each document has one of these.
#
#  **Signature packet**: an xml file that contains information about the signing
#  of a document. A document may have one or more of these.
#
#  **Missing document**: the document packet contains a reference to the
#  document content (pdf). When that content is not found on the file system it
#  is considered missing.
#
#  **Corrupt document**: when the document xml cannot be parsed (This is not
#  a corruption of the actual submitted content.)
#
#  **Invalid document hash**: PatentSafe creates a hash of the submitted content
#  (document) and stores that in the document xml. The checker creates
#  its own internal hash and compares the two. If the checker hash differs
#  from the PatentSafe hash it is considered invalid.
#
#  **Skipped document**: when the checker cannot generate the document hash
#  (due to a missing library) this check is skipped and the document
#  cannot be considered validated.
#
#  **Corrupt signature**: when the signature xml cannot be parsed.
#
#  **Missing public key**: PatentSafe users have a public key that is used
#  during the signing process. The signature xml retains a copy of that
#  key. If it can't be found it is considered missing.
#
#  **Missing signatures**: the document xml retains a reference to the signature
#  packets that are created during signing. If that signature packet cannot
#  be found in the repo it is reported missing.
#
#  **Invalid signature text**: the signature packet retains a reference to the
#  text displayed to the user during signing. The checker generates an
#  internal version of this and compares it to the original. If they differ
#  the signature text is considered invalid.
#
#  **Invalid content hash**: the signature packet retains a reference to the
#  PatentSafe calculated hash of the document content. The checker generates
#  an internal copy of this hash, compares it to the signature's copy and if
#  they are different it is considered invalid.
#
#  **Invalid signature**: if the public key can't be found or the signature,
#  content hash or public key are invalid the signature is considered invalid.
#
#  **Skipped signature**: if the checker cannot generate SHA512 hashes (due to a
#  missing library) then signature validation is skipped.
#
#  **Documents without hash**: it is possible that a document packet is missing
#  the PatentSafe calculated hash.
#
# == Summary report
#
#   * Run at - the time the checker ran against a repository
#   * Document packets checked
#   * Signature packets checked
#
# === If known exceptions are available the following values are calculated:
#
#   * Document packets skipped
#   * Signature packets skipped
#
# === If errors are found the following values are calculated:
#
#   * Missing documents
#   * Corrupt documents
#   * Invalid document hashes
#   * Skipped documents
#   * Corrupt signatures
#   * Missing public key
#   * Missing signatures
#   * Invalid signature texts
#   * Invalid content hashes
#   * Invalid signatures
#   * Skipped signatures*
#
# === All successful checks are calculated each time:
#
#   * Documents w/o hash
#   * Document hashes
#   * Public keys found
#   * Signature texts
#   * Content hashes
#   * Valid signatures
#
# === If the SHA512  hashes cannot be created a note is included in the report:
#
#   Hashes and public_keys could not be validated as the installed
#   version of OpenSSL does not support SHA512.
#
# == Author
#   Amphora Research Systems, Ltd.
#
# == Copyright
#   Copyright (c) 2006-2014 Amphora Research Systems Ltd.
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

# libraries required for the script to function
require 'base64'
require 'date'
require 'digest'
require 'fileutils'
require 'logger'
require 'optparse'
require 'openssl'
require 'ostruct'
require 'pathname'
require 'rexml/document'
require 'time'
require 'yaml'
require 'rubygems'

# setup the logger if this is the main file
if __FILE__ == $PROGRAM_NAME
  LOG = Logger.new(STDOUT)
end


# App is a wrapper around the operations needed to process PatentSafe
# repository files. It handles options parsing, control flow for the
# script and help output.
#
# To see what is really happening - jump to the process_command method
#
class App
  VERSION = '5.5'

  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin

    # set defaults
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
  end

  # Parse options, check arguments, then process the command
  def run
    # install custom formatter
    LOG.formatter = LogFormat.new

    if parsed_options? && arguments_valid?
      # set log level
      if @options.verbose
        LOG.level = Logger::INFO
      elsif @options.quiet
        LOG.level = Logger::ERROR
      else
        # The default is WARN
        LOG.level = Logger::WARN
      end
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
      opts.on('-v', '--version')             { output_version ; exit 0 }
      opts.on('-h', '--help')                { output_help }
      opts.on('-V', '--verbose')             { @options.verbose = true }
      opts.on('-s', '--skip')                { @options.skip = true }
      opts.on('-q', '--quiet')               { @options.quiet = true }
      opts.on('-y', '--year [yyyy]')         { |yyyy| @options.year = yyyy }
      opts.on('-c', '--csv')                 { @options.format = 'csv' }
      opts.on('-j', '--json')                { @options.format = 'json' }
      opts.on('-x', '--exceptions [expath]') { |expath| @options.exceptions_path = expath }

      opts.parse!(@arguments) rescue return false
      process_options
      true
    end

    # Performs post-parse processing on options
    def process_options
      @options.verbose = false if @options.quiet

      if @options.exceptions_path
        # check if file passed in on -x is there
        unless File.exist?(@options.exceptions_path)
          LOG.fatal "Exception list cannot be found at '#{@options.exceptions_path}'. Check the path and try again."
          exit
        end

        # can the file be loaded?
        begin
          @known_exceptions = YAML.load_file(@options.exceptions_path)
        rescue
          LOG.fatal "Exception list at '#{@options.exceptions_path}' could not be loaded. Please check the file format."
          exit
        end
      end

    end

    def output_options
      puts "Options:\n"

      @options.marshal_dump.each do |name, val|
        puts "  #{name} = #{val}"
      end
    end

    # True if required arguments were provided
    def arguments_valid?
      true if @arguments.length == 1
    end

    # Setup the arguments
    def process_arguments
      @patentsafe_dir = ARGV[0] if ARGV[0]

      # path must exist
      unless File.exists?(@patentsafe_dir)
        LOG.error "PatentSafe path #{@patentsafe_dir} does not exist!"
        exit
      end

      # It is useful to have the repository as a global variable
      $repository_root = @patentsafe_dir
    end

    def output_help
      puts version_text
      # RDoc::usage() #exits app
      # TODO output proper options
      puts @options
    end

    def output_usage
      # TODO output proper options
      puts @options
      # RDoc::usage('usage') # gets usage from comments above
    end

    def output_version
      puts version_text
      puts OptionParser::Version.join('.')
      # puts RDoc::usage('copyright')
    end

    def version_text
      "#{File.basename(__FILE__)} version #{VERSION}"
    end

    # The guts of pscheck
    def process_command
      LOG.info ""
      LOG.info version_text
      LOG.info "-----------------------------------------------------------------------"
      repo = Repository.new(
        :base_path        => @patentsafe_dir,
        :year             => @options.year,
        :known_exceptions => @known_exceptions,
        :verbose          => @options.verbose,
        :skip_validation  => @options.skip,
        :repofile         => @options.repofile,
        :format           => @options.format
      )

      repo.check
    end

end


# Repository is a wrapper around the functions specific to the repo.
# It handles path formatting, loading users, loading signatures
class Repository
  attr_accessor :verbose
  attr_accessor :path
  attr_reader :results, :customer_id, :installation_id, :server_id, :timestamp, :document_count, :bit_count

  def initialize(options={})
    # base_path, year=nil, verbose=false
    @path             = options[:base_path]
    @year             = options[:year]
    @known_exceptions = options[:known_exceptions] || {}
    @verbose          = options[:verbose] || false
    @skip_validation  = options[:skip_validation]
    @repofile         = options[:repofile]
    @format           = options[:format].to_s.downcase if options[:format]

    @repofile, @docfile, @sigfile = if @format
      ["repository.#{@format}", "documents.#{@format}", "signatures.#{@format}"]
    end

    @users            = Hash.new

    # results storage
    @results          = OpenStruct.new
    @results.errors   = Hash.new

    # document info
    @results.missing_documents        = 0
    @results.corrupt_documents        = 0
    @results.invalid_document_hashes  = 0
    @results.nohash_documents         = 0
    @results.skipped_documents        = 0
    @results.checked_documents        = 0
    @results.known_documents_skipped  = 0
    @results.missing_signatures       = 0

    # signature info
    @results.corrupt_signatures       = 0
    @results.missing_keys             = 0
    @results.invalid_signature_texts  = 0
    @results.invalid_content_hashes   = 0
    @results.invalid_signatures       = 0
    @results.skipped_signatures       = 0
    @results.checked_signatures       = 0
    @results.known_signatures_skipped = 0
  end

  def self.columns
    ["Customer ID", "Installation ID", "Server ID", "Timestamp", "Document Count", "Bit Count"]
  end

  def to_row
    [customer_id, installation_id, server_id, timestamp, document_count, bit_count]
  end

  def openssl_sha512?
    @openssl_sha512 ||= OpenSSL::Digest::SHA512.hexdigest('TEST') ==
      "7bfa95a688924c47c7d22381f20cc926f524beacb13f84e203d4bd8cb6ba2fce81c57a5f059bf3d509926487bde925b3bcee0635e4f7baeba054e5dba696b2bf"
  rescue
    nil
  end

  def output_time
    @check_started_at || Time.now
  end

  def output_path
    @output_path ||= "output"/"#{@server_id}"/"#{output_time.strftime('%Y%m%d-%H%M%S')}"
  end

  def config_path
    "#{@path}"/'config.xml'
  end

  def id_values_path
    # Deal with older (4.x) id path
    [ "#{data_path}"/'config'/'id-values.xml',
      "#{data_path}"/'id-values.xml' ].find do |path|
      File.exists?(path)
    end
  end

  def data_path
    "#{@path}"/'data'
  end

  def users_path
    "#{data_path}"/'users'
  end

  # path to check
  def check_path
    path = @year ? "#{data_path.to_pattern}/#{@year}" : "#{data_path.to_pattern}"
  end

  # Performs the checks on the repository
  def check
    @check_started_at = Time.now
    LOG.info "PatentSafe Check Start at #{@check_started_at}\n"

    unless openssl_sha512?
      LOG.fatal "!! OpenSSL Digest does not support SHA512 - signatures can not be validated. !!\n"
    end

    unless @known_exceptions.empty?
      LOG.info "** known file exceptions list loaded (all signatures for these documents will be skipped)"

      @known_exceptions.each do |docid,comment|
        LOG.info " - #{docid}: #{comment}"
      end

      LOG.info ""
      LOG.info "** #{@known_exceptions.length} known file exceptions loaded"
      LOG.info ""
    end

    load_configuration
    load_timestamp
    load_users
    validate_documents
    validate_signatures

    @check_finished_at = Time.now
    @check_run_minutes = "%.3f" % ((@check_finished_at - @check_started_at)/60).to_s

    LOG.info "\nPatentSafe Check Finished at #{@check_finished_at}"
    LOG.info "\nPatentSafe Check Finished in #{@check_run_minutes} minutes"

    # Only produce the output files if required
    finish_output_files if @format
    generate_summary_report
  end

  # Loads the config from the xml in the repo
  def load_configuration
    LOG.info ""
    LOG.info "** loading configuration from #{config_path}"

    configuration     = Configuration.new(:path => config_path, :verbose => @verbose)
    @customer_id      = configuration.customer_id
    @installation_id  = configuration.installation_id
    @server_id        = configuration.server_id

    LOG.info ""
    LOG.info "** configuration for #{@server_id} loaded"
  end

  # Loads last event from the repo as a "timestamp"
  def load_timestamp
    LOG.info ""
    LOG.info "** loading repository timestamp"

    log_path = nil

    # look for events.log
    v4_log_path = "#{data_path}/events.log"

    if File.exists?(v4_log_path)
      LOG.info "** events.log found"
      log_path = v4_log_path
    else
      # use last file in the most recent year/month/day
      if year_dirs = Dir["#{data_path.to_pattern}/[0-9]???"].reverse
        year_dirs.find do |year_dir|
          Dir["#{year_dir}/[0-9]?"].reverse.find do |month_dir|
            Dir["#{month_dir}/[0-9]?"].reverse.find do |day_dir|
              events_txt_path = "#{day_dir}/events.txt"
              log_path = events_txt_path if File.exists?(events_txt_path) && !File::Stat.new(events_txt_path).zero?
            end
          end # month
        end # year
      else
        LOG.info "  - ERROR: Can't find year directories!"
      end
    end
    LOG.info " - log found at #{log_path}"

    events      = Events.new(:path => log_path, :verbose => @verbose)
    last_event  = events.last

    LOG.info ""
    if last_event.occurred.nil?
      LOG.info "** could not load repository timestamp"
    else
      @timestamp = last_event.occurred
      LOG.info "** repository timestamp is: #{@timestamp}"
    end
  end

  # Loads users from the xml in the repo
  def load_users
    LOG.info ""
    LOG.info "** loading users from #{users_path}"

    Dir["#{users_path.to_pattern}/**/*.xml"].each do |path|
      user = User.new(:path => path, :verbose => @verbose)
      # store it for use later
      @users[user.user_id] = user
    end

    LOG.info ""
    LOG.info "** #{@users.length} users loaded"
  end

  # Loads and validates documents from the xml in the repo
  def validate_documents
    LOG.info ""
    LOG.info "** checking #{'and validating' unless @skip_validation} documents"

    Dir["#{check_path}/**/docinfo.xml"].each do |path|
      begin
        # load the document
        document = Document.new(:path => path, :sha512 => openssl_sha512?, :verbose => @verbose)
      rescue REXML::ParseException => e
        @results.corrupt_documents += 1
        @results.checked_documents += 1
        # move on to the next document
        next
      end

      # check if this is a known exception
      if exception_comment = @known_exceptions[document.document_id]
        LOG.info ""
        LOG.info " * skipping #{document.document_id} at #{document.path}"

        # skip this file
        @results.known_documents_skipped += 1

        LOG.info "  - SKIPPED: Known exception [#{exception_comment}]" if exception_comment
      else
        # perform validation
        doc_errors = document.validate unless @skip_validation

        # did the doc have a hash?
        @results.nohash_documents += 1 unless document.hash_exists?

        @results.checked_documents += 1

        if @docfile
          @doc_formatter ||= Formatter.new(output_path, @docfile, Document.columns, @format)
          @doc_formatter.format(document.to_row)
        end

        # tally errors here to save time
        if doc_errors && !doc_errors.empty?
          @results.errors[document.document_id] = doc_errors
          @results.missing_documents        += 1 if doc_errors[:content_missing]
          @results.invalid_document_hashes  += 1 if doc_errors[:invalid_document_hash]
          @results.skipped_documents        += 1 if doc_errors[:skipped_document]
          @results.missing_signatures       += doc_errors[:signature_missing].length if doc_errors[:signature_missing]
        end
      end
    end

    LOG.info ""
    LOG.info "** documents checked #{'and validated' unless @skip_validation}"
  end

  # Loads and validates signatures from the xml in the repo
  def validate_signatures
    LOG.info ""
    LOG.info "** checking #{'and validating' unless @skip_validation} signatures"

    Dir["#{check_path}/**/signature-*.xml"].each do |path|
      begin
        # load the signature
        signature = Signature.new(:path => path, :sha512 => openssl_sha512?, :verbose => @verbose)
      rescue REXML::ParseException => e
        @results.corrupt_signatures += 1
        @results.checked_signatures +=1
        # move on to the next signature
        next
      end

      # check if this is a known exception
      if exception_comment = @known_exceptions[signature.document_id]
        LOG.info ""
        LOG.info " * skipping #{signature.signature_id} at #{signature.path}"

        # skip this file
        @results.known_signatures_skipped += 1

        LOG.info "  - SKIPPED: Known exception [#{exception_comment}]" if exception_comment
      else
        unless @skip_validation
          # perform validation
          sig_errors = signature.validate

          # First try with the origin server ID and username in serverid_userid format first,
          # to avoid any ambiguity if there is another user, with the same ID on the target server.
          server_signer_id = signature.signer_id.include?('_') ? nil : "#{signature.server_id}_#{signature.signer_id}"

          # We run this special case only if there's no server ID embedded in the user name in the first place, otherwise it's a normal check
          if (server_signer_id && @users[server_signer_id])
            # this is an imported user so there is no public key to verify against hence we're happy with this one
          elsif @users[signature.signer_id] && @users[signature.signer_id].keys.include?(signature.public_key)
            # check if user public key can be found
            LOG.info "  - OK:  User public key is consistent with database"
          else
            LOG.error "  - ERROR: #{signature.signature_id unless @verbose} User public key not found: #{signature.signer_id}/#{signature.server_id} (this may not be a problem - make sure you can find the identity certificate)"
            sig_errors[:missing_key] = {signature.public_key => signature.signer_id}
          end
        end

        @results.checked_signatures += 1
        # add the sig to the array if needed
        #@sigs <<  signature.to_row if @sigfile
        if @sigfile
          @sig_formatter ||= Formatter.new(output_path, @sigfile, Signature.columns, @format.to_s.downcase.to_sym)
          @sig_formatter.format(signature.to_row)
        end

        # tally errors here to save time
        if sig_errors && !sig_errors.empty?
          @results.errors[signature.signature_id] = sig_errors
          @results.missing_keys             += 1 if sig_errors[:missing_key]
          @results.invalid_signature_texts  += 1 if sig_errors[:invalid_signature_text]
          @results.invalid_content_hashes   += 1 if sig_errors[:invalid_content_hash]
          @results.invalid_signatures       += 1 if sig_errors[:invalid_signature]
          @results.skipped_signatures       += 1 if sig_errors[:skipped_signature]
        end
      end
    end

    LOG.info ""
    LOG.info "** signatures checked #{'and validated' unless @skip_validation}"
  end

  private

    def finish_output_files
      repoFormatter = Formatter.new(output_path, @repofile, Repository.columns, @format.to_s.downcase.to_sym)
      repoFormatter.format(self.to_row)
      repoFormatter.close
      @doc_formatter.close
      @sig_formatter.close
    end

    # Format all the results for the summary report
    def generate_summary_report
      dtotal = @results.checked_documents
      stotal = @results.checked_signatures

      LOG.warn ""
      LOG.warn "-----------------------------------------------------------------------"
      LOG.warn "PatentSafe Checker Summary Report for #{@path}"
      LOG.warn "-----------------------------------------------------------------------"
      LOG.warn "Run at:                     #{@check_started_at}"
      LOG.warn "Run time:                   #{@check_run_minutes} minutes"
      LOG.warn ""
      LOG.warn "Document packets checked:   #{dtotal}"
      LOG.warn "Signature packets checked:  #{stotal}#{'*' unless openssl_sha512?}"
      unless @known_exceptions.empty?
        LOG.warn ""
        LOG.warn "Known Exceptions:"
        LOG.warn "Document packets skipped:  #{@results.known_documents_skipped}"
        LOG.warn "Signature packets skipped: #{@results.known_signatures_skipped}"
      end
      LOG.warn ""

      hasErrors =
        @results.missing_documents > 0 ||
        @results.corrupt_documents > 0 ||
        @results.invalid_document_hashes > 0 ||
        @results.skipped_documents > 0 ||
        @results.corrupt_signatures > 0 ||
        @results.missing_keys > 0 ||
        @results.missing_signatures > 0 ||
        @results.invalid_signature_texts > 0 ||
        @results.invalid_content_hashes > 0 ||
        @results.invalid_signatures > 0 || openssl_sha512? ||
        @results.skipped_signatures > 0

      if !@results.errors.empty? || hasErrors
        LOG.warn "-- Errors --"
        LOG.warn " Missing documents:         #{@results.missing_documents}" if @results.missing_documents > 0
        LOG.warn " Corrupt documents:         #{@results.corrupt_documents}" if @results.corrupt_documents > 0
        LOG.warn " Invalid document hashes:   #{@results.invalid_document_hashes}" if @results.invalid_document_hashes > 0
        LOG.warn " Skipped documents:         #{@results.skipped_documents}" if @results.skipped_documents > 0
        LOG.warn " Corrupt signatures:        #{@results.corrupt_signatures}" if @results.corrupt_signatures > 0
        LOG.warn " Missing public key:        #{@results.missing_keys}" if @results.missing_keys > 0
        LOG.warn " Missing signatures:        #{@results.missing_signatures}" if @results.missing_signatures > 0
        LOG.warn " Invalid signature texts:   #{@results.invalid_signature_texts}" if @results.invalid_signature_texts > 0
        LOG.warn " Invalid content hashes:    #{@results.invalid_content_hashes}" if @results.invalid_content_hashes > 0
        LOG.warn " Invalid signatures:        #{@results.invalid_signatures}" if @results.invalid_signatures > 0 || openssl_sha512?
        LOG.warn " Skipped signatures*:       #{@results.skipped_signatures}" if @results.skipped_signatures > 0
        LOG.warn ""
      end

      LOG.warn "-- Successful checks --"
      LOG.warn " Documents w/o hash:        #{@results.nohash_documents}" if @results.nohash_documents > 0
      LOG.warn " Document hashes:           #{dtotal - @results.invalid_document_hashes - @results.nohash_documents}" if !@skip_validation && openssl_sha512?
      LOG.warn " Public keys found:         #{stotal - @results.missing_keys}"
      LOG.warn " Signature texts:           #{stotal - @results.invalid_signature_texts}"
      LOG.warn " Content hashes:            #{stotal - @results.invalid_content_hashes}" if !@skip_validation && openssl_sha512?
      LOG.warn " Valid signatures:          #{stotal - @results.invalid_signatures}" if !@skip_validation && openssl_sha512?
      LOG.warn ""
      LOG.fatal "  * Hashes and public_keys could not be validated as the installed " unless openssl_sha512?
      LOG.fatal "    version of OpenSSL does not support SHA512." unless openssl_sha512?
      LOG.warn "-----------------------------------------------------------------------"
      LOG.warn ""
    end
end


module RepositoryXML
  attr_accessor :verbose, :path, :content, :xml

  def exists?
    @path && File.exists?(@path)
  end

  def parsed?
    @xml.nil? ? false : true
  end

  def extract(options)
    @path     = options[:path]
    @verbose  = options[:verbose] || false
    @content  = options[:content]
  end

  # Parse an XML document
  def parse_xml
    @xml = File.exists?(@path) ? REXML::Document.new(File.read(@path)) : nil
  end

  # Parse a fragment of XML
  def parse_content
    @xml = REXML::Document.new("<root>\n#{@content}\n</root>") if @content
  rescue REXML::ParseException => pe
    LOG.error "There was a problem parsing #{@path}"
    nil
  end
end


# Config is a wrapper around the config xml document
class Configuration
  include RepositoryXML

  attr_reader :server_id, :customer_id, :installation_id

  def initialize(options={})
    extract options

    if parse_xml
      _server_id        = @xml.root.elements["ServerId"]
      # @customer_id      = _server_id.get_text("CustomerId").value().to_s
      @customer_id      = get_text(_server_id, "CustomerId", "UNKNOWN")
      # @installation_id  = _server_id.get_text("InstallationId").value().to_s
      @installation_id  = get_text(_server_id, "InstallationId", "00")
      @server_id        = "#{@customer_id}#{@installation_id}"
    else
      LOG.error "Unable to find configuration file: "+ @path
      exit
    end
  end

  def get_text(node, name, default)
    if text = node.get_text(name)
      text.value().to_s
    else
      default
    end
  end
end


# IdValues is a wrapper around the id-values xml document
class IdValues
  include RepositoryXML

  attr_reader :ids

  def initialize(options={})
    extract options

    @ids = {}

    if parse_xml
      @xml.root.elements.each("id-value") do |id|
        @ids[id.attribute("serverId").to_s] = id.attribute("count").to_s
      end
    end
  end

end


# User is a wrapper around the user xml document
class User
  include RepositoryXML

  attr_reader :version, :user_id, :name, :keys

  def initialize(options={})
    extract options

    @keys = Array.new

    if @path && parse_xml
      @version  = @xml.root.attribute("version").to_s
      @user_id  = @xml.root.attribute("userId").to_s
      @name     = @xml.root.get_text("name").value().to_s
      key       = @xml.root.elements["keyPair"]

      @keys << key.get_text("encodedKey").value().to_s if key

      # load old keys too
      keys_path = File.join(File.split(@path)[0], "#{@user_id.downcase}.keys")

      if File.exist?( keys_path )
        keys_xml = REXML::Document.new("<keys>#{File.open(keys_path, "r").read}</keys>")
        keys_xml.root.elements.each("keyPair") do |old_key|
          @keys << old_key.get_text("encodedKey").value().to_s
        end
      end

      LOG.info " - loaded #{@name} [#{@user_id}] with #{@keys.length} keys"
    end
  end

end


# Document is a wrapper around the document xml document
class Document
  include RepositoryXML

  # document attributes
  attr_reader :document_id, :document_type, :content_name, :hash, :signature_ids, :signature_paths

  def initialize(options={})
    extract options

    @sha512 = options[:sha512] || false
    @errors = Hash.new


    if @path && parse_xml
      root            = @xml.root
      @document_id    = root.attribute("docId").to_s
      @document_type  = root.attribute("type").to_s
      if @document_type == 'digital'
        @document_type = 'experiment'
      end
      cn              = root.elements["content/name"]
      @content_name   = cn ? cn.text : "UNKNOWN"
      h               = root.elements["hash[@format='sha512']"]

      if h
        @hash_exists  = true
        @hash         = h.text.to_s
      else
        @hash_exists  = false
        @hash         = nil
      end

      # signature_ids is an array of ids for signatures that have a state of "Signed"
      @signature_ids  = []
      root.get_elements("signatures/signature").each{ |s| @signature_ids << s.attribute("sigId").to_s if s.get_text("state").value().to_s.downcase == "signed" }

      pn                = Pathname.new(path)
      # trim signature id to get the file suffix: TEST0100000037S001 (last 3 digits)
      @signature_paths  = @signature_ids.map{ |sid| File.join(pn.dirname,"signature-#{sid[15..17]}.xml") }
    end

  end

  def self.columns
    ["Document ID", "Hash", "Type", "File Name", "File Path"]
  end

  def to_row
    [document_id, hash, document_type, content_name, content_relative_path]
  end

  # This is the absolute path
  def content_path
    File.dirname(path).to_s/content_name
  end

  # This is the relative path - relative to the start of the repository
  def content_relative_path
    remove_repository_base(File.dirname(path).to_s/content_name)
  end

  def content_txt_path
    File.dirname(path).to_s/"content.txt"
  end

  def sha512?
    @sha512
  end

  def hash_exists?
    @hash_exists
  end

  def generated_hash
    @generated_hash ||= Digest::SHA512.hexdigest(File.open(content_path, "rb").read)
  end

  def hash_valid?
    @hash_valid ||= (generated_hash == hash)
  end

  def has_signatures?
    signature_ids.length > 0
  end

  # returns hash of errors
  def validate
    LOG.info ""
    LOG.info " * validating #{document_id} at #{path}"

    if File.exists?(content_path)
      if hash_exists?
        if hash_valid?
          LOG.info "  - OK:  Generated document hash is consistent with #{content_name}"
        else
          if sha512?
            LOG.error "  - ERROR: #{document_id unless verbose} Generated document hash is inconsistent with #{content_name}"
            @errors[:invalid_document_hash] = [generated_hash, hash]
          else
            LOG.info "  - SKIPPED:  Document hash cannot be validated without OpenSSL SHA512 support"
            @errors[:skipped_document] = true
          end
        end # hash_valid?
      else
        # If a document doesn't have a hash then it can still be valid!
        # LOG.info "  - SKIPPED:  Document type '#{document_type}' has no hash"
        # @errors[:skipped_document] = true
      end # check_hash?
    else
      LOG.error "  - ERROR: Document content expected at #{content_path}"
      @errors[:content_missing] = path
    end

    # test if signature files are on disk
    signature_paths.inject(false) do |exists, path|
      sig_exists = File.exists?(path)

      if sig_exists
        LOG.info "  - OK:  Document signature found at #{path}"
      else
        LOG.error "  - ERROR: Document signature expected at #{path}"
        @errors[:signature_missing] ||= []
        @errors[:signature_missing] << path
      end
    end if has_signatures?

    @errors
  end

  # same checks as validate but without messages
  def valid?
    # hash consistent?
    (hash_valid? if check_hash?)
  end
end


# Signature is a wrapper around the signature xml document
class Signature
  include RepositoryXML

  # signer attributes
  attr_reader :signer_id, :signer_name, :public_key, :role
  # signature attributes
  attr_reader :signature_id, :server_id, :document_id, :content_filename, :content_hash, :wording, :date, :text, :value

  def initialize(options={})
    extract options

    @sha512 = options[:sha512] || false
    @errors = Hash.new

    if @path && parse_xml
      root              = @xml.root
      raise REXML::ParseException, "Unable to create XML parser, possibly empty file? : " unless root

      @signature_id     = root.attribute("sigId").to_s
      @server_id        = @signature_id[0..5].downcase
      @document_id      = @signature_id[0..13] # first 13 characters
      @signer_id        = root.elements["signer"].attribute("userId").value()
      @signer_name      = root.get_text("signer").value()
      @public_key       = root.get_text("publicKey").value().to_s.strip
      @role             = root.get_text("role").value()
      @content_filename = root.elements["signedContent"].attribute("filename").value()
      @content_hash     = root.get_text("signedContent").value().to_s.strip
      @wording          = root.get_text("affirmedWording").value()
      @date             = root.get_text("signatureDate").value()
      @text             = root.get_text("signatureText").value()
      @value            = root.get_text("signatureValue").value()
    end
  end

  def self.columns
    ["Signature ID", "Document ID", "Role", "Signer ID", "Signer Name", "Signer Key", "Content Path", "Content Hash", "Acceptance Text", "Signature Date", "Signature Text", "Signature Hash"]
  end

  def to_row
    [signature_id, document_id, role, signer_id, signer_name, public_key, signed_content_relative_path, content_hash, wording, date, text, value]
  end

  # This is the absolute path
  def signed_content_path
    File.dirname(path).to_s/content_filename
  end

  # This is the relative path - relative to the start of the repository
  def signed_content_relative_path
    remove_repository_base(File.dirname(path).to_s/content_filename)
  end

  # Internally generated for comparison
  def generated_signature_text
    "~~#{signer_id}~~#{wording}~~#{date}~~#{content_hash}~~"
  end

  def signature_text_valid?
    generated_signature_text == text
  end

  def sha512?
    @sha512
  end

  # Internally generated for comparison
  def generated_content_hash
    @generated_content_hash ||= Digest::SHA512.hexdigest(File.open(signed_content_path, "rb").read)
  end

  def content_hash_valid?
    @content_hash_valid ||= (generated_content_hash == @content_hash)
  end

  def generated_public_key
    @generated_public_key ||= OpenSSL::PKey::RSA.new(Base64.decode64(public_key))
  # on Windows the key isn't loaded, we get a hard error
  rescue OpenSSL::PKey::RSAError => e
    false
  end

  def public_key_valid?
    if sha512? && generated_public_key
      @public_key_valid ||= (generated_public_key.verify(OpenSSL::Digest::SHA512.new, Base64.decode64(value), text))
    else
      false
    end
  end

  # signer_db_keys< Array> of keys
  # returns hash of errors
  def validate
    LOG.info ""
    LOG.info " * validating #{signature_id} at #{path}"

    if File.exists?(signed_content_path)
      if signature_text_valid?
        LOG.info "  - OK:  Generated signature text is consistent with signature packet"
      else
        LOG.error "  - ERROR: #{signature_id unless verbose} Generated signature text is inconsistent with signature packet"
        @errors[:invalid_signature_text] = [generated_signature_text, text]
      end

      if content_hash_valid?
        LOG.info "  - OK:  Generated document hash is consistent with signature packet"
      else
        LOG.error "  - ERROR: #{signature_id unless verbose} Generated document hash is inconsistent with signature packet"
        @errors[:invalid_content_hash] = [generated_content_hash, content_hash]
      end
    else
      LOG.error "  - ERROR: #{signature_id unless verbose} Cannot validate document hash for missing document at #{signed_content_path}"
      @errors[:missing_content] = signed_content_path
    end

    if public_key_valid?
      LOG.info "  - OK:  Signature is valid"
    else
      if sha512?
        LOG.error "  - ERROR: #{signature_id unless verbose} Signature is invalid [#{signature_id}]"
        @errors[:invalid_signature] = [generated_public_key, value]
      else
        LOG.info "  - SKIPPED:  Signature cannot be validated without OpenSSL SHA512 support"
        @errors[:skipped_signature] = true
      end
    end

    @errors
  end

  # same checks as validate but without messages
  def valid?
    # public key in file consistent with db?
    # signature text consistent?
    # hash consistent?
    # signature value consistent?
    @signer_db_keys.include?(@public_key) &&
    signature_text_valid? &&
    content_hash_valid? &&
    public_key_valid?
  end

end


class Events
  include RepositoryXML

  def initialize(options={})
    extract options
  end

  def last
    last_line = ""
    File.open(@path, 'r'){ |f| f.each { |line| last_line = line } } if exists?
    Event.new(:path => @path, :content => last_line, :verbose => @verbose)
  end

end


class Event
  include RepositoryXML

  # attributes we care about
  attr_accessor :event_type, :occurred_at, :occurred

  def initialize(options={})
    extract options

    if @content && parse_content
      if _event = @xml.root.elements["event"]
        @event_type   = _event.attribute("type").to_s
        @occurred     = _event.attribute("occured").to_s
        @occurred_at  = Time.parse(@occurred)
      end
    end
  end

  def to_s
    @content
  end
end


# Default/base output Formatter
class Formatter

  def initialize(out_dir_path, out_file_name, columns, format = "csv")
    @is_first_row = true

    # include the formatter we need to use
    self.class.instance_eval("include #{format.to_s.capitalize}Formatter")

    if (out_dir_path)
      FileUtils.mkdir_p(out_dir_path)
      out_path = "#{out_dir_path}"/out_file_name
      @out_file = File.open(out_path , "w+")
    end

    @columns    = columns
    @col_count  = columns.length
    @out_file.print header
  end

  def format(rows)
    @out_file.print row(rows, @is_first_row)
    @is_first_row = false
  end

  def quote(val)
    %Q|"#{val}"|
  end

  def close
    @out_file.print footer
    @out_file.close
  end
end


# Format a 'row' in csv format
module CsvFormatter
  def header
    @columns.map{|v| quote(v)}.join(",") + "\n"
  end

  def row(r, is_first_row)
    r.map{|v| quote(v)}.join(",") + "\n"
  end

  def footer
    ""
  end
end


# Format a 'row' in json format - makes the object look like a hash
module JsonFormatter
  def header
    "["
  end

  def row(r, is_first_row)
    out = ""
    out << (is_first_row ? "\n  {" : ",\n  {")
    @columns.each_with_index do |col, i|
       out << "#{quote(col)}:#{quote(r[i])}"
       out << (i == @col_count-1 ? "" : ",")
    end
    out << "}"
    out
  end

  def footer
    "\n]\n"
  end
end


# Logger formatter
class LogFormat < Logger::Formatter
  def call(severity, time, program_name, message)
    # datetime      = time.strftime("%Y-%m-%d %H:%M")
    "#{message}\n"
  end
end


# Extension to string
class String
  # / gives a pretty clear way to join path information
  def /(str_to_join)
    path = File.join(self, str_to_join)
    # if win32 switch / to \\
    path.gsub!(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR) if is_windows?
    path
  end

  # switches \\ or \ to / for dir pattern search
  def to_pattern
    is_windows? ? self.gsub!(/\\|\\\\/,"/") : self
  end

end



# Use a variety of techniques to determine if we're on a Windows platform
def is_windows?
  return true if ENV['OS'] =~ /Windows/i
  return true if RUBY_PLATFORM =~ /win32/i
  return true if RUBY_PLATFORM =~ /mingw32/i
  return true if RUBY_PLATFORM =~ /mswin/i

  # If we got this far, assume we're on something other than Windows
  return false
end


# Remove the Repository's base pathname from a path, so it becomes relative to the start of the Repository
def remove_repository_base(pathname)
  # Sometimes it might be nil or small
  if pathname == nil || pathname.size == 0
    return pathname
  else
    # Just replace the repository root with nothing
    return pathname.gsub($repository_root , "")
  end
end

# Patch REXML for thread safety
# module REXML::Encoding
#   @mutex = Mutex.new
#   def self.apply(obj, enc)
#     @mutex.synchronize { @encoding_methods[enc][obj] }
#   end
# end


# Only run the app if this was called from the command line rather than included as a library
if __FILE__ == $PROGRAM_NAME
    # Create and run the application
    app = App.new(ARGV, STDIN)
    app.run
end
