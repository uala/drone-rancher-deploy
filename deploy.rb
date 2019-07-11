#!/usr/bin/env ruby
# Stdlibs
require 'yaml'
require 'erb'
require 'logger'
# Gemfile stuff
require 'bundler/setup'
Bundler.require(:default)


# Check current branch
current_branch = ENV['DRONE_SOURCE_BRANCH']
logger.debug %Q{Running plugin for branch "#{current_branch}"}
logger.info "Reading plugin configuration from file #{ENV['PLUGIN_CONFIG']}"


# Check applicable envs
if environments.empty?
  logger.warn "No matching environments for #{current_branch}, deploy won't happen"
  exit 0
else
  logger.info "Will deploy to environment(s): #{environments.keys}"
end

# Actual deploy steps
environments.each do |name, config|
  logger.debug "Running on agent #{ENV['DRONE_MACHINE']}, deploying to project #{config['project']} at #{config['server_url']}"
  # Login command
  logger.info "Logging in to rancher at #{config['server_url']} and selecting first project"
  shell.run('rancher login', config['server_url'], '-t', "#{config['access_key']}:#{config['secret_key']}", in: echo_1)
  # Context switch
  context_command = %Q{rancher context switch #{config['project']}}
  logger.info "Switching context to #{config['project']}"
  logger.debug context_command
  shell.run('rancher', 'context', 'switch', config['project'])
  # Deploy services
  logger.info "Updating services: #{config['services']} with image '#{image_name(config)}'"
  config['services'].each do |service|
    logger.debug "Updating service #{service}"
    shell.run("rancher kubectl set image deployment #{service} #{service}=#{image_name(config)}", '-n', config['namespace'])
  end
end
