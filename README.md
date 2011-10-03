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
    -d, --docfile     Filename to output list of documents
    -s, --sigfile     Filename to output list of signatures
    -c, --csv         Output docfile/sigfile in csv format [Default]
    -j, --json        Output docfile/sigfile in json format
    -x, --exceptions  Path to file with a list of known exceptions


## Exceptions File

Files listed in this file are skipped during validation. Known exception file
format - each file listed on a new line with a space after the :, e.g.
`DOCID: Explanation/comment/note`. Here is an example.

    AMPH9900011803: This file is corrupt because the hard-drive crashed
    AMPH9900011804: This file is known to be corrupt 20 Apr 07

# About this document

This document is formatted using
[Markdown](http://daringfireball.net/projects/markdown/)