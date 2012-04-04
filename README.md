# About the PatentSafe Checker

## Overview

The PatentSafe Checker is a simple Ruby script which can be used to check the
integrity of a [PatentSafe](http://www.amphora-research.com/products/patentsafe.html)
repository. It checks for both document and signature validity.

Note that this functionality is also built into the Custodian's Console, which
is a commercial product available from
[Amphora Research Systems](http://www.amphora-research.com/corporate/contactUs.html).


## License & Availability

The script is made available under the GPL v3, to ensure that everyone with a
repository produced by PatentSafe can check it (even if they don't have a
license for PatentSafe). If you improve this script for your own purposes,
we'd be delighted if you felt able to share your changes.


# Using the Checker Script

## Requirements

The Checker script requires Ruby 1.8, preferably a recent version with an
updated SSL which does SHA-512 hashes.


## Usage Instructions

### Examples

    ruby pscheck.rb

    ruby pscheck.rb -q /path/to/repository

    ruby pscheck.rb --verbose /path/to/repository

    ruby pscheck.rb -y 2007 -v /path/to/repository


### Command Line Usage

To run the checker `ruby pscheck.rb [options] path_to_repository`


For help use: `ruby pscheck.rb -h`

### Options:

    -h, --help        Displays help message
    -v, --version     Display the version, then exit
    -q, --quiet       Output as little as possible, overrides verbose
    -V, --verbose     Verbose output
    -y, --year        Only scan year given
    -c, --csv         Output docfile/sigfile in csv format [Default]
    -j, --json        Output docfile/sigfile in json format
    -x, --exceptions  Path to file with a list of known exceptions


## Exceptions File

Files listed in this file are skipped during validation. Known exception file
format - each file listed on a new line with a space after the :, e.g.
`DOCID: Explanation/comment/note`. Here is an example.

    AMPH9900011803: This file is corrupt because the hard-drive crashed
    AMPH9900011804: This file is known to be corrupt 20 Apr 07

## Summary report definitions

 The checker generates a summary report at the end of process. This report
 contains information on what is checked and the results of those checks.

 Some definitions may help understand what these calculations mean:

 **Document packet**: an xml file that contains information about the
 submitted document. Each document has one of these.

 **Signature packet**: an xml file that contains information about the signing
 of a document. A document may have one or more of these.

 **Missing document**: the document packet contains a reference to the 
 document content (pdf). When that content is not found on the file system it 
 is considered missing.

 **Corrupt document**: when the document xml cannot be parsed (This is not
 a corruption of the actual submitted content.)

 **Invalid document hash**: PatentSafe creates a hash of the submitted content
 (document) and stores that in the document xml. The checker creates
 its own internal hash and compares the two. If the checker hash differs
 from the PatentSafe hash it is considered invalid.

 **Skipped document**: when the checker cannot generate the document hash
 (due to a missing library) this check is skipped and the document
 cannot be considered validated.

 **Corrupt signature**: when the signature xml cannot be parsed.

 **Missing public key**: PatentSafe users have a public key that is used
 during the signing process. The signature xml retains a copy of that
 key. If it can't be found it is considered missing.

 **Missing signatures**: the document xml retains a reference to the signature
 packets that are created during signing. If that signature packet cannot
 be found in the repo it is reported missing.

 **Invalid signature text**: the signature packet retains a reference to the
 text displayed to the user during signing. The checker generates an
 internal version of this and compares it to the original. If they differ
 the signature text is considered invalid.

 **Invalid content hash**: the signature packet retains a reference to the
 PatentSafe calculated hash of the document content. The checker generates
 an internal copy of this hash, compares it to the signature's copy and if
 they are different it is considered invalid.

 **Invalid signature**: if the public key can't be found or the signature,
 content hash or public key are invalid the signature is considered invalid.

 **Skipped signature**: if the checker cannot generate SHA512 hashes (due to a
 missing library) then signature validation is skipped.

 **Documents without hash**: it is possible that a document packet is missing
 the PatentSafe calculated hash.


## Summary report

  * Run at - the time the checker ran against a repository
  * Document packets checked
  * Signature packets checked

### If known exceptions are available the following values are calculated:

  * Document packets skipped
  * Signature packets skipped

### If errors are found the following values are calculated:

  * Missing documents
  * Corrupt documents
  * Invalid document hashes
  * Skipped documents
  * Corrupt signatures
  * Missing public key
  * Missing signatures
  * Invalid signature texts
  * Invalid content hashes
  * Invalid signatures
  * Skipped signatures*

### All successful checks are calculated each time:

  * Documents w/o hash
  * Document hashes
  * Public keys found
  * Signature texts
  * Content hashes
  * Valid signatures

### If the SHA512  hashes cannot be created a note is included in the report:

  Hashes and public_keys could not be validated as the installed
  version of OpenSSL does not support SHA512.

# About this document

This document is formatted using
[Markdown](http://daringfireball.net/projects/markdown/)