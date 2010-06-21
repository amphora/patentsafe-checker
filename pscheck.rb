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
#   -y, --year          Only scan year given
#   -x, --exceptions    Path to file with a list of known exceptions
#                       these files are skipped during validation
#
#   Known exception file format - each file listed on a new line with 
#   a space after the :
#
#   DOCID: Explanation/comment/note
#   -----------------------------------------------------------------
#   i.e.:
#   AMPH9900011803: This file is corrupt because the hard-drive crashed
#   AMPH9900011804: This file is known to be corrupt 20 Apr 07
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

# libraries required for the script to function
require 'optparse' 
require 'rdoc/usage'
require 'ostruct'
require 'date'
require 'rexml/document' 
require 'base64'
require 'digest'
require 'openssl'
require 'logger'
require 'yaml'

# setup our logger STDOUT for now
LOG = Logger.new(STDOUT)


# App is a wrapper around the operations needed to process PatentSafe 
# repository files. It handles options parsing, control flow for the 
# script and help output. 
#
# To see what is really happening - jump to the process_command method
#
class App
  VERSION = '4.8'

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
        LOG.level = Logger::FATAL
      else
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
      opts.on('-v', '--version')      { output_version ; exit 0 }
      opts.on('-h', '--help')         { output_help }
      opts.on('-V', '--verbose')      { @options.verbose = true }  
      opts.on('-q', '--quiet')        { @options.quiet = true }
      opts.on('-y', '--year [yyyy]')  { |yyyy| @options.year = yyyy }
      opts.on('-x', '--exceptions [expath]')   { |expath| @options.exceptions_path = expath }
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
    end
    
    def output_help
      puts version_text
      RDoc::usage() #exits app
    end
    
    def output_usage
      RDoc::usage('usage') # gets usage from comments above
    end
    
    def output_version
      puts version_text
      puts RDoc::usage('copyright')
    end
    
    def version_text
      "#{File.basename(__FILE__)} version #{VERSION}"
    end
    
    # The guts of pscheck
    def process_command
      log ""
      log version_text
      log "-----------------------------------------------------------------------"
      repo = Repository.new(:base_path => @patentsafe_dir, 
                            :year => @options.year, 
                            :known_exceptions => @known_exceptions,
                            :verbose => @options.verbose)
      repo.check
    end
    
    # wrapper around logger call
    def log(msg, severity="unknown")
      LOG.send(severity.to_sym, msg)
    end
end


# Repository is a wrapper around the functions specific to the repo.
# It handles path formatting, loading users, loading signatures 
class Repository
  attr_accessor :verbose
  attr_accessor :path
  attr_reader :results
  
  def initialize(options={})
    # base_path, year=nil, verbose=false
    @path = options[:base_path]
    @year = options[:year]
    @known_exceptions = options[:known_exceptions] || {}
    @verbose = options[:verbose] || false
    @users = Hash.new
    # results storage
    @results                          = OpenStruct.new
    @results.errors                   = Hash.new
    @results.corrupt_signatures       = 0
    @results.missing_keys             = 0
    @results.invalid_signature_texts  = 0
    @results.invalid_content_hashes   = 0
    @results.invalid_signatures       = 0
    @results.skipped_signatures       = 0
    @results.checked_signatures       = 0
    @results.known_files_skipped      = 0
  end

  def openssl_sha512?
    @openssl_sha512 ||= OpenSSL::Digest::SHA512.hexdigest('TEST') == 
      "7bfa95a688924c47c7d22381f20cc926f524beacb13f84e203d4bd8cb6ba2fce81c57a5f059bf3d509926487bde925b3bcee0635e4f7baeba054e5dba696b2bf"
  rescue
    nil
  end
  
  def data_path
    "#{@path}"/'data'
  end
  
  def users_path
    "#{data_path}"/'users'
  end

  # Performs the checks on the repository
  def check
    @check_started_at = DateTime.now
    LOG.info "PatentSafe Check Start at #{@check_started_at}\n"
    
    unless openssl_sha512?
      log "!! OpenSSL Digest does not support SHA512 - signatures can not be validated. !!\n"
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
    
    load_users
    validate_signatures
    
    @check_finished_at = DateTime.now    
    LOG.info "\nPatentSafe Check Finished at #{@check_finished_at}"
    
    generate_summary_report
  end
  
  # Loads users from the xml in the repo
  def load_users
    LOG.info "** loading users from #{users_path}"
    
    Dir["#{users_path.to_pattern}/**/*.xml"].each do |path|
      user = User.new(:path => path,
                      :verbose => @verbose)
      # store it for use later
      @users[user.user_id] = user
    end
    
    LOG.info ""
    LOG.info "** #{@users.length} users loaded"
  end
  
  # Loads and validates signatures from the xml in the repo
  def validate_signatures
    LOG.info ""
    LOG.info "** validating signatures"
    
    path = @year ? "#{data_path.to_pattern}/#{@year}" : "#{data_path.to_pattern}"
    
    Dir["#{path}/**/signature-*.xml"].each do |path|
      begin
        # load the signature
        signature = Signature.new(:path => path, 
                                  :sha512 => openssl_sha512?, 
                                  :verbose => @verbose)
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
        @results.known_files_skipped += 1
        
        LOG.info "  - SKIPPED: Known exception [#{exception_comment}]" if exception_comment
      else
        # perform validation
        sig_errors = signature.validate
        
        # check if user public key can be found
        if @users[signature.signer_id].keys.include?(signature.public_key)
          LOG.info "  - OK:  User public key is consistent with database"
        else
          LOG.error "  - ERROR: #{signature.signature_id unless @verbose} User public key not found (this may not be a problem - make sure you can find the identity certificate)"
          sig_errors[:missing_key] = {signature.public_key => signature.signer_id}
        end
        
        @results.checked_signatures += 1
        
        # tally errors here to save time
        unless sig_errors.empty?
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
    LOG.info "** signatures validated"
  end
  
  private 
  
    # Format all the results for the summary report
    def generate_summary_report
      total = @results.checked_signatures
      log ""
      log "-----------------------------------------------------------------------"
      log "PatentSafe Checker Summary Report"
      log "-----------------------------------------------------------------------"
      log "Run at:                     #{@check_started_at}"
      log ""
      log "Signatures packets checked: #{total}"
      unless @known_exceptions.empty?
        log "Signatures packets skipped: #{@results.known_files_skipped} (Known exceptions)"
      end
      log ""
      unless @results.errors.empty?
        log "-- Errors --" 
        log " Corrupt signatures:        #{@results.corrupt_signatures}" if @results.corrupt_signatures > 0
        log " Missing public key:        #{@results.missing_keys}" if @results.missing_keys > 0
        log " Invalid signature texts:   #{@results.invalid_signature_texts}" if @results.invalid_signature_texts > 0
        log " Invalid content hash:      #{@results.invalid_content_hashes}" if @results.invalid_content_hashes > 0
        log " Invalid signatures:        #{@results.invalid_signatures}" if @results.invalid_signatures > 0 || openssl_sha512?
        log " Skipped signatures*:       #{@results.skipped_signatures}" if @results.skipped_signatures > 0
        log ""
      end
      log "-- Successful checks --"
      log " Public keys found:         #{total - @results.missing_keys}"
      log " Signature texts:           #{total - @results.invalid_signature_texts}"
      log " Content hashes:            #{total - @results.invalid_content_hashes}"
      log " Valid signatures:          #{total - @results.invalid_signatures}" if openssl_sha512?
      log " Validated signatures*:     #{total - @results.skipped_signatures}"
      log ""
      log "  * Signatures could not be validated as the installed " unless openssl_sha512?
      log "    version of OpenSSL does not support SHA512." unless openssl_sha512?
      log "-----------------------------------------------------------------------"            
      log ""
    end
    
    # wrapper around logger call
    def log(msg, severity="unknown")
      LOG.send(severity.to_sym, msg)
    end
end


# User is a wrapper around the user xml document
class User
  attr_accessor :verbose
  attr_reader :version, :user_id, :name, :keys
  
  def initialize(options={})
    # path, verbose=false
    @path = options[:path]
    @verbose = options[:verbose] || false
    @keys = Array.new
    
    if @path
      @xml = REXML::Document.new(File.read(@path))
      # load the document on initialize "eagerly"
      @version = @xml.root.attribute("version").to_s
      @user_id = @xml.root.attribute("userId").to_s
      @name = @xml.root.get_text("name").value().to_s
      key = @xml.root.elements["keyPair"]
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


# Signature is a wrapper around the signature xml document
class Signature
  attr_accessor :verbose
  # signer attributes
  attr_reader :signer_id, :signer_name, :public_key, :role
  # signature attributes
  attr_reader :path, :signature_id, :document_id, :content_filename, :content_hash, :wording, :date, :text, :value
  
  def initialize(options={})
    # path, sha512=false, verbose=false
    @path = options[:path]
    @sha512 = options[:sha512] || false
    @verbose = options[:verbose] || false
    @errors = Hash.new    
    if @path
      @xml = REXML::Document.new(File.open(path))
      @signature_id = @xml.root.attribute("sigId").to_s
      @document_id = @signature_id[0..13] # first 13 characters
      @signer_id = @xml.root.elements["signer"].attribute("userId").value()
      @signer_name = @xml.root.get_text("signer").value()
      @public_key = @xml.root.get_text("publicKey").value().to_s.strip
      @role = @xml.root.get_text("role").value()
      @content_filename = @xml.root.elements["signedContent"].attribute("filename").value()
      @content_hash = @xml.root.get_text("signedContent").value().to_s.strip
      @wording = @xml.root.get_text("affirmedWording").value()
      @date = @xml.root.get_text("signatureDate").value()
      @text = @xml.root.get_text("signatureText").value()
      @value= @xml.root.get_text("signatureValue").value()
    end
  end
  
  def signed_content_path
    File.dirname(@path).to_s/@content_filename
  end
  
  # Internally generated for comparison
  def generated_signature_text
    "~~#{@signer_id}~~#{@wording}~~#{@date}~~#{@content_hash}~~"
  end
  
  def signature_text_valid?
    generated_signature_text == @text
  end
  
  # Internally generated for comparison
  def generated_content_hash
    # use the stored value if we have it
    @generated_content_hash ||= Digest::SHA512.hexdigest(File.open(signed_content_path, "rb").read)
  # rescue
  #   nil
  end
  
  def content_hash_valid?
    @content_hash_valid ||= (generated_content_hash == @content_hash)
  end
  
  def generated_public_key
    @generated_public_key ||= OpenSSL::PKey::RSA.new(Base64.decode64(@public_key))
  # on Windows the key isn't loaded, we get a hard error
  rescue OpenSSL::PKey::RSAError => e
    false    
  end

  def public_key_valid?
    if @sha512 && generated_public_key
      @public_key_valid ||= (generated_public_key.verify(OpenSSL::Digest::SHA512.new, Base64.decode64(@value), @text))
    else
      false
    end
  end
  
  # signer_db_keys< Array> of keys
  # returns hash of errors
  def validate
    LOG.info ""
    LOG.info " * validating #{@signature_id} at #{@path}"
    
    if signature_text_valid?
      LOG.info "  - OK:  Generated signature text is consistent with signature packet"
    else
      LOG.error "  - ERROR: #{@signature_id unless @verbose} Generated signature text is inconsistent with signature packet"
      @errors[:invalid_signature_text] = [@generated_signature_text, @text] 
    end
    
    if content_hash_valid?
      LOG.info "  - OK:  Generated document hash is consistent with signature packet"
    else
      LOG.error "  - ERROR: #{@signature_id unless @verbose} Generated document hash is inconsistent with signature packet"
      @errors[:invalid_content_hash] = [@generated_content_hash, @content_hash]
    end
    
    if public_key_valid?
      LOG.info "  - OK:  Signature is valid"
    else
      if @sha512
        LOG.error "  - ERROR: #{@signature_id unless @verbose} Signature is invalid [#{@signature_id}]"
        @errors[:invalid_signature] = [@generated_public_key, @value]
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
    path.gsub!(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR) if RUBY_PLATFORM =~ /win32/i
    path
  end
  
  # switches \\ or \ to / for dir pattern search
  def to_pattern
    RUBY_PLATFORM =~ /win32/i ? self.gsub!(/\\|\\\\/,"/") : self
  end  
  
end


# Create and run the application
app = App.new(ARGV, STDIN)
app.run