require 'rancher_deployer/version'
require 'logger'

module RancherDeployer

  class TagChecker
    # attr_reader :logger, :config, :current_branch

    def initialize
    end

    def enforce_tag_on_branch?
      on_tag? && !requested_branch.to_s.empty?
    end

    def check!
      unless enforce_tag_on_branch?
        logger.info 'Tag checking not enabled, everything is ok' and return true
      end
      # Get branchs for current tag
      branches_for_tag = branches_for_tag(current_commit)
      logger.info "Checking if tag: #{current_tag} (#{current_commit}) is included in #{branches_for_tag}"
      unless branches_for_tag.include?(requested_branch)
        logger.error "User has requested that tag should be on branch #{requested_branch}, it only was in #{branches_for_tag}"
        ::Kernel.exit(1)
      end
      logger.debug "Check passed, all done"
    end

    def branches_for_tag(tag_name)
      `git branch --contains #{tag_name}`.split(/\s+/)
    end

    private
    
    def current_tag
      ENV['DRONE_TAG']
    end

    def current_commit
      ENV['DRONE_COMMIT']
    end

    def on_tag?
      !ENV['DRONE_TAG'].to_s.empty?
    end

    def requested_branch
      ENV.fetch('PLUGIN_ENFORCE_BRANCH_FOR_TAG', nil)
    end

    # Logger for output
    def logger
      @_logger ||= begin
        Logger.new($stdout).tap do |l|
          l.level = ENV.fetch('PLUGIN_LOGGING', 'debug')
        end
      end
    end
  end
end
