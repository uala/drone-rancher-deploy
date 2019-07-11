#!/usr/bin/env ruby
# Stdlibs
require 'yaml'
require 'erb'
require 'logger'
# Gemfile stuff
require 'bundler/setup'
Bundler.require(:default)

# Dry-run flag
def dry_run?
  ENV['PLUGIN_DRY_RUN'] && !ENV['PLUGIN_DRY_RUN'].empty?
end

def color?
  ENV.fetch('PLUGIN_COLORS', 'true') != 'false'
end

# Logger for output
def logger
  @_logger ||= begin
    Logger.new($stdout).tap do |l|
      l.level = ENV.fetch('PLUGIN_LOGGING', 'debug')
    end
  end
end

# Image name to use for new deployment
def image_name(config)
  config.fetch('image') do
    image_prefix = config.fetch('image_prefix', 'drone')
    branch_slug  = ENV['DRONE_SOURCE_BRANCH'].to_s.gsub(/\/+/, '-')
    short_sha    = ENV['DRONE_COMMIT_SHA'].to_s[0, 8]
    "#{ENV['DRONE_REPO']}:#{image_prefix}-#{branch_slug}-#{short_sha}"
  end
end

# shell wrapper
def shell
  @_cmd ||= TTY::Command.new(logger: logger, dry_run: dry_run?, color: color?)
end

def on_tag?
  !ENV['DRONE_TAG'].to_s.empty?
end

def should_deploy?(name, config, current_branch)
  # Skip dot names, used for templates
  return false if name.start_with?('.')
  # Check for tag deployments
  if on_tag?
    logger.debug "Running on git tag, checking tag flag #{config['only_tags']}"
    return config['only_tags'] === true
  end
  # Generic match based on regexp
  regexp = Regexp.new("^#{config['branch']}$")
  logger.debug "Matching branch regexp #{regexp} with current branch #{current_branch}: #{regexp.match?(current_branch)}"
  regexp.match?(current_branch) && config['only_tags'] != true
end

def echo_1
  StringIO.new.tap do |st|
    st.puts '1'
    st.rewind
  end
end

# Check current branch
current_branch = ENV['DRONE_SOURCE_BRANCH']
logger.debug %Q{Running plugin for branch "#{current_branch}"}
logger.info "Reading plugin configuration from file #{ENV['PLUGIN_CONFIG']}"

# Parse configuration file also using ERB
APP_CONFIG = YAML.load(ERB.new(File.read(ENV['PLUGIN_CONFIG'])).result)

# Find applicable configurations, using branch key of configuration and skip templates starting with dots
environments = APP_CONFIG.select { |name, config| should_deploy?(name, config, current_branch) }

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
