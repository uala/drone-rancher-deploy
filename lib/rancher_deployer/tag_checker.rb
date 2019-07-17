require 'rancher_deployer/version'
require 'logger'

module RancherDeployer

  class TagChecker
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

    def branches_for_tag(tag_name, repo_path = Dir.pwd)
      @branches ||= begin
        repo = Rugged::Repository.new(repo_path)
        repo.remotes['origin'].fetch if fetch?
        # Convert tag to sha1 if matching tag found
        full_sha = repo.tags[tag_name] ? repo.tags[tag_name].target_id : tag_name
        logger.debug "Inspecting repo at #{repo.path}, branches are #{repo.branches.map(&:name)}"
        # descendant_of? does not return true for it self, i.e. repo.descendant_of?(x, x) will return false for every commit
        # @see https://github.com/libgit2/libgit2/pull/4362
        repo.branches.select { |branch| repo.descendant_of?(branch.target_id, full_sha) || full_sha == branch.target_id }
            .map(&:name).map { |br| br.sub(%r{^origin/}, '') }.uniq # Remove the origin/ prefix from branch names
      end
    end

    private

    def fetch?
      !ENV['PLUGIN_FETCH'].to_s.empty?
    end

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
          l.level = ENV.fetch('PLUGIN_LOGGING', 'info')
        end
      end
    end
  end
end
