# Cauchy

[![Build Status](https://api.travis-ci.com/cotap/cauchy.svg?token=PQCDXv39wYQSK1Gnq72A&branch=master)](https://magnum.travis-ci.com/cotap/cauchy)
[![Gem Version](https://badge.fury.io/rb/cauchy.svg)](https://badge.fury.io/rb/cauchy)

Cauchy manages your ES Index Schemas.

## Installation

Install the Cauchy gem globally with

    $ gem install cauchy

And verify your install with

    $ cauchy version

## Usage

### Setup

To get started, create a new Cauchy project structure

    $ cauchy init --path=/some/place/special

This will create the following structure

```
├── config.yml
└── schema
```

Configure Cauchy's `config.yml` with your elasticsearch settings. You can find more information about the available options at the [ElasticSearch Transport docs](http://www.rubydoc.info/gems/elasticsearch-transport).

### Creating an Index Schema

To create a new index schema, simply

    $ cauchy new [index_schema_name]

This will generate a new template schema file located in your `schemas/` directory.

### Applying your schema

Once you've configuring your schema, you're ready to apply it to ES with

    $ cauchy apply [index_schema_name]

__Note:__ the schema name is optional here, and if left blank, Cauchy will run against all your defined schemas

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/cotap/cauchy.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

