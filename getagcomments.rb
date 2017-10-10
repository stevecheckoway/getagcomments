#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

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
  return nil unless check(config, 'branch')
  config
end

def main
  if ARGV.length != 1
    STDERR.puts("Usage: #{$PROGRAM_NAME} CONFIG_FILE")
    exit(1)
  end

  # Use Faraday middleware.
  Octokit.middleware = Faraday::RackBuilder.new do |builder|
    builder.use(Faraday::HttpCache, serializer: Marshal, shared_cache: false)
    builder.use(Octokit::Response::RaiseError)
    builder.adapter(Faraday.default_adapter)
  end

  # Use auto pagination
  Octokit.auto_paginate = true

  config = load_config(ARGV[0])
  exit(1) if config.nil?

  client = Octokit::Client.new(:access_token => config['token'])
  organization = config['organization']
  prefix = config['assignment'] + '-'

  # Iterate over each repo in the organization.
  for repo in client.org_repos(organization)
    # Examine only those that start with the prefix.
    repo_name = repo.name
    next unless repo_name.start_with?(prefix)

    full_name = organization + '/' + repo_name

    # Get the members.
    members = {}
    team = client.repo_teams(full_name)[0]
    if team.nil?
      login = repo_name[prefix.length..-1]
      members[login] = client.user(login).name
    else
      for member in client.team_members(team.id)
        login = member.login
        members[login] = client.user(login).name
      end
    end

    # Look for config['branch'].
    commit = nil
    client.branches(full_name).each do |branch|
      next unless branch.name == config['branch']
      commit = branch.commit.sha
      break
    end

    # Get the most recent comment made by the bot.
    comment = nil
    date = nil
    if commit
      client.commit_comments(full_name, commit).each do |c|
        if c.user.login == client.login
          comment = c.body
          date = c.created_at.getlocal
        end
      end
    end

    # Print some information about the repo.
    puts "- name: #{repo_name}"
    puts "  members:"
    members.each do |login, name|
      puts "    - \"#{name} (#{login})\""
    end
    puts "  commit: #{commit || 'null'}"
    if comment
      puts "  date: \"#{date}\""
      puts "  comment: |"
      puts(comment.lines.map {|line| '    ' + line}.join(''))
    else
      puts "  comment: null"
    end
    puts ""
  end
end

if __FILE__ == $0
  main
end


# vim: set sw=2 sts=2 ts=8 expandtab:
