RSpec.describe RancherDeployer::TagChecker do
  before { stub_env 'PLUGIN_LOGGING', 'error' }
  before { skip('Set INTEGRATION_SPEC=true to execute') unless ENV['INTEGRATION_SPEC'] }
  before { stub_env 'PLUGIN_FETCH', 'true' }

  def clone_as_drone_io(repo_path, reference, repo: 'https://github.com/fabn/draw-with-git')
    # Remove repo folder
    FileUtils.rm_rf(repo_path) if File.directory?(repo_path)
    # Make a repo
    FileUtils.mkdir(repo_path)
    # Initialize git repo with bare git commands
    shell = TTY::Command.new(output: Logger.new('/dev/null'))
    shell.run('git init .', chdir: repo_path, only_output_on_error: true)
    shell.run('git remote add origin https://github.com/fabn/draw-with-git', chdir: repo_path)
    shell.run("git fetch origin +refs/#{reference}:", chdir: repo_path)
    shell.run('git checkout -qf FETCH_HEAD', chdir: repo_path)
  end

  let(:repo_path) { File.realpath("#{__dir__}/../../draw-with-git") }

  shared_examples_for 'branches for tag' do |tag, branches|
    it %Q{should return #{branches} for "#{tag}"} do
      expect(subject.branches_for_tag(tag, repo_path)).to match_array(branches)
    end
  end

  describe 'with a repo as cloned by drone.io executor for branches' do
    before(:all) do
      repo_path = File.realdirpath("#{__dir__}/../../draw-with-git")
      clone_as_drone_io(repo_path, 'heads/master')
    end

    include_examples 'branches for tag', 'on-all-branches', %w(develop feature/foo master)
    include_examples 'branches for tag', 'only-on-master', %w(master)
    include_examples 'branches for tag', 'only-on-develop', %w(develop)
    include_examples 'branches for tag', 'only-on-feature', %w(feature/foo)
    include_examples 'branches for tag', 'only-on-remote', %w(feature/only-remote)
  end

  context 'with a repo as cloned by drone.io executor for tags' do
    # Setup only once repository
    before(:all) do
      repo_path = File.realdirpath("#{__dir__}/../../draw-with-git")
      clone_as_drone_io(repo_path, 'tags/only-on-master')
    end

    include_examples 'branches for tag', 'on-all-branches', %w(develop feature/foo master)
    include_examples 'branches for tag', 'only-on-master', %w(master)
    include_examples 'branches for tag', 'only-on-develop', %w(develop)
    include_examples 'branches for tag', 'only-on-feature', %w(feature/foo)
    include_examples 'branches for tag', 'only-on-remote', %w(feature/only-remote)

    context 'with a generic commit' do
      let(:commit_sha) { '8fb27644af03808d34882f1d7a7b35f3940b0d7b' }
      it 'should return matching branches (develop feature/foo master)' do
        expect(subject.branches_for_tag(commit_sha, repo_path)).to match_array(%w(develop feature/foo master))
      end
    end
  end
end