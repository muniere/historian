# historian

## Overview

Collect command histories from remote hosts.

## Requirements

- [Ruby](https://www.ruby-lang.org/) >= 2.1.0
- [Rake](http://docs.seattlerb.org/rake/) >= 10.0.0

## Get started

```bash
# clone
$ git clone git@github.com:muniere/historian.git

# install
$ rake install

# uninstall
$ rake uninstall

# status
$ rake status

# execute: detect hosts from command history
$ historian -v

# execute: specify hosts from cli parameter
$ historian -v host1.yourdomain host2.yourdomain

# execute: specify date to collect histories
$ historian -v -d 2014-01-01 

# help
$ historian -h
```
