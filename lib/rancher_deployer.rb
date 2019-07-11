require 'rancher_deployer/version'
require 'yaml'
require 'erb'
require 'logger'

module RancherDeployer
  class Error < StandardError;
  end

  # When configuration file is not found or not set
  MissingConfig = Class.new(Error)

  class Deployer
    attr_reader :logger, :config, :current_branch

    def initialize
      @config = {}
    end

    def load_config!
      config_file = validate_config!
      logger.debug { "Reading configuration from #{config_file}" }
      # Parse configuration file also using ERB
      @config = YAML.load(ERB.new(File.read(config_file)).result)
    end

    def environments
      load_config! if config.empty?
      config.select { |name, config| should_deploy?(name, config) }
    end

    # Image name to use for new deployment
    def image_name
      config.fetch('image') do
        image_prefix = config.fetch('image_prefix', 'drone')
        branch_slug  = ENV['DRONE_SOURCE_BRANCH'].to_s.gsub(/\/+/, '-')
        short_sha    = ENV['DRONE_COMMIT_SHA'].to_s[0, 8]
        repo         = ENV['DRONE_REPO'].downcase
        "#{repo}:#{image_prefix}-#{branch_slug}-#{short_sha}"
      end
    end

    def on_tag?
      !ENV['DRONE_TAG'].to_s.empty?
    end

    # Dry-run flag
    def dry_run?
      !ENV['PLUGIN_DRY_RUN'].to_s.empty?
    end

    def color?
      ENV.fetch('PLUGIN_COLORS', 'true') != 'false'
    end

    private

    # Predicate used to check if a configuration must be deployed
    def should_deploy?(name, config)
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

    # Return a shell wrapper
    def shell
      @_cmd ||= TTY::Command.new(logger: logger, dry_run: dry_run?, color: color?)
    end

    # Used as stdin for login command
    def echo_1
      StringIO.new.tap do |st|
        st.puts '1'
        st.rewind
      end
    end

    # Logger for output
    def logger
      @_logger ||= begin
        Logger.new($stdout).tap do |l|
          l.level = ENV.fetch('PLUGIN_LOGGING', 'debug')
        end
      end
    end

    def validate_config!
      if ENV['PLUGIN_CONFIG'].to_s.empty?
        raise MissingConfig, %q{No configuration file set, please configure using ENV['PLUGIN_CONFIG']}
      end
      raise MissingConfig, "No configuration at #{ENV['PLUGIN_CONFIG']}" unless File.exists?(ENV['PLUGIN_CONFIG'])
      File.realpath(ENV['PLUGIN_CONFIG'])
    end
  end
end
