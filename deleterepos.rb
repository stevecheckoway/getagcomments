#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'optparse'

require 'octokit'
require 'faraday-http-cache'
require 'yaml'

def check(config, key)
  missing = config[key].nil?
  if missing
    STDERR.puts("Required config file parameter '#{key}' missing")
  end
  !missing
end

def load_config(path)
  begin
  config = YAML.load_file(path)
  rescue SystemCallError => e
    STDERR.puts(e.to_s)
    return nil
  end
  return nil unless check(config, 'token')
  return nil unless check(config, 'organization')
  return nil unless check(config, 'assignment')
  config
end

def main
  cl_token = nil
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options] CONFIG_FILE..."
    opts.on("-t", "--token=TOKEN") do |token|
      cl_token = token
    end
  end.parse!
  if ARGV.length == 0
    STDERR.puts("Usage: #{$PROGRAM_NAME} [options] CONFIG_FILE...")
    exit(1)
  end

  organization = nil
  token = nil
  prefixes = []

  ARGV.each do |path|
    config = load_config(path)
    abort("Cannot load or parse file #{path}") if config.nil?
    organization = config['organization'] if organization.nil?
    abort("Different organizations") if organization != config['organization']
    if cl_token.nil?
      token = config['token'] if token.nil?
      abort("Different tokens") if token != config['token']
    end
    prefixes.push(config['assignment'] + '-')
  end

  token = cl_token unless cl_token.nil?

  # Use Faraday middleware.
  Octokit.middleware = Faraday::RackBuilder.new do |builder|
    builder.use(Faraday::HttpCache, serializer: Marshal, shared_cache: false)
    builder.use(Octokit::Response::RaiseError)
    builder.adapter(Faraday.default_adapter)
  end

  # Use auto pagination
  Octokit.auto_paginate = true

  client = Octokit::Client.new(:access_token => token)

  to_delete = []
  # Iterate over each repo in the organization.
  for repo in client.org_repos(organization)
    # Examine only those that start with the prefix.
    repo_name = repo.name
    to_delete.push(repo_name) if prefixes.any? { |prefix| repo_name.start_with?(prefix) }
  end

  puts("Repositories to delete:")
  to_delete.each { |repo| puts("  " + repo) }
  print("Proceed (y/[n])? ")
  response = $stdin.gets&.strip
  abort("Deletion cancelled") if response != 'y'

  success = true
  for repo in to_delete
    if !client.delete_repo(organization + '/' + repo)
      puts "Failed to delete repository #{repo}"
      success = false
    end
  end
  !success
end

if __FILE__ == $0
  main
end


# vim: set sw=2 sts=2 ts=8 expandtab:
