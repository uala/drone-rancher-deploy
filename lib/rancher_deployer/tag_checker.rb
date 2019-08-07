require 'rancher_deployer/version'
require 'logger'

module RancherDeployer

  class TagChecker
    def enforce_tag_on_branch?
      on_tag? && !requested_branch.to_s.empty?
    end

    def enforce_head?
      enforce_tag_on_branch? && !ENV.fetch('PLUGIN_ENFORCE_HEAD', nil).to_s.empty?
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
      if enforce_head? && !tag_is_on_head?(current_tag, requested_branch)
        logger.error "User has requested that tag #{current_tag} should be on head of branch #{requested_branch}, it was not, skipping deployment"
        ::Kernel.exit(1)
      end
      logger.debug 'Check passed, all done'
    end

    def branches_for_tag(tag_name, repo_path = Dir.pwd)
      @branches ||= begin
        repo = Rugged::Repository.new(repo_path)
        update_remote!(repo) if fetch?
        # Convert tag to sha1 if matching tag found
        full_sha = repo.tags[tag_name] ? repo.tags[tag_name].target_id : tag_name
        logger.debug "Inspecting repo at #{repo.path}, branches are #{repo.branches.map(&:name)}"
        # descendant_of? does not return true for it self, i.e. repo.descendant_of?(x, x) will return false for every commit
        # @see https://github.com/libgit2/libgit2/pull/4362
        repo.branches.select { |branch| repo.descendant_of?(branch.target_id, full_sha) || full_sha == branch.target_id }
            .map(&:name).map { |br| br.sub(%r{^origin/}, '') }.uniq # Remove the origin/ prefix from branch names
      end
    end

    def tag_is_on_head?(tag_name, head = requested_branch, repo_path = Dir.pwd)
      logger.info "Checking if tag #{tag_name} matches with branch #{head} HEAD"
      repo = Rugged::Repository.new(repo_path)
      update_remote!(repo) if fetch?
      full_sha = repo.tags[tag_name] ? repo.tags[tag_name].target_id : tag_name
      branch_sha = (repo.branches[head] || repo.branches["origin/#{head}"]).target_id
      full_sha == branch_sha
    end

    def git_credentials
      @git_credentials ||= begin
        credentials = Netrc.read(credentials_file)['github.com']
        logger.debug "Successfully parsed credentials from #{credentials_file}" if credentials
        credentials
      end
    end

    private

    def update_remote!(repo)
      logger.debug "Checking fetch connection against repo at #{ENV['DRONE_REPO']} (required authentication: #{require_authentication?})"
      credentials = rugged_credentials(git_credentials)
      if repo.remotes['origin'].check_connection(:fetch, credentials: credentials)
        logger.info 'Connection succeded, fetching all refs in origin'
        repo.remotes['origin'].fetch(credentials: credentials)
        logger.info "Fetched all refs from remote repository at #{ENV['DRONE_REPO']}"
      end
    end

    def rugged_credentials(credentials)
      credentials ?
          Rugged::Credentials::UserPassword.new(username: credentials.login, password: credentials.password) :
          Rugged::Credentials::Default.new # Empty set of credentials
    end
    
    def require_authentication?
      ENV['DRONE_REPO_PRIVATE'] && File.exists?(File.expand_path('~/.netrc'))
    end

    def credentials_file
      File.expand_path('~/.netrc')
    end

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
