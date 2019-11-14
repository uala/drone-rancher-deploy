RSpec.describe RancherDeployer::Deployer do
  before { stub_env 'PLUGIN_LOGGING', 'error' }
  before { stub_env 'DRONE_SOURCE_BRANCH', 'develop' }

  describe '#load_config!' do
    context 'when config file is not set' do
      it 'raises missing config error' do
        expect {
          subject.load_config!
        }.to raise_error RancherDeployer::MissingConfig, /PLUGIN_CONFIG/
      end
    end
    context 'when config file does not exist' do
      before { stub_env 'PLUGIN_CONFIG', 'no-such-file.yml' }
      it 'raises missing config error' do
        expect {
          subject.load_config!
        }.to raise_error RancherDeployer::MissingConfig, /No configuration at/
      end
    end

    context 'when file exist' do
      let(:access_key) { 'access-key-123' }
      before { stub_env 'PLUGIN_CONFIG', "#{__dir__}/config.yml" }
      before { stub_env 'RANCHER_ACCESS_KEY', access_key }
      before { subject.load_config! }
      it 'load it into attr_reader' do
        expect(subject.config).to be_a(Hash)
      end

      it 'parses YAML with anchors' do
        expect(subject.config['develop']['branch']).to eq('develop')
        expect(subject.config['develop']['namespace']).to eq('backend')
      end

      it 'parses ERB tags' do
        expect(subject.config['develop']['access_key']).to eq(access_key)
      end
    end
  end

  describe '#environments' do
    let(:current_branch) { 'develop' }
    before { stub_env 'PLUGIN_CONFIG', "#{__dir__}/config.yml" }
    before { allow(subject).to receive(:current_branch).and_return(current_branch) }

    it 'select all applicable environments' do
      expect(subject.environments.size).to be > 0
    end

    context 'when on tag' do
      before { allow(subject).to receive(:on_tag?).and_return(true) }
      it 'should only deploy configs with only_tags' do
        expect(subject.environments.keys).to match_array('production')
      end
    end

    context 'when in branches' do
      before { allow(subject).to receive(:on_tag?).and_return(false) }
      it 'should not select dot configs' do
        expect(subject.environments.keys).not_to include('.env-config')
      end

      it 'should not select matching branches with only_tag option' do
        expect(subject.environments.keys).not_to include('production')
      end

      context 'when using regexp' do
        let(:current_branch) { 'feature/foo' }

        it 'should select matching branches using the given regexp' do
          expect(subject.environments.keys).to include('feature')
        end
      end

    end
  end

  describe '#current_branch' do
    before { stub_env 'DRONE_SOURCE_BRANCH', 'master' }
    it 'should fetch it from DRONE_SOURCE_BRANCH' do
      expect(subject.current_branch).to eq('master')
    end
  end

  describe '#deploy!' do
    context 'when environments are empty' do
      before { allow(subject).to receive(:environments).and_return({}) }
      it 'should log and return' do
        expect(subject.send(:logger)).to receive(:warn).with(/No matching environments/)
        subject.deploy!
      end
    end

    context 'with matching environments' do
      let(:shell) { double(:shell).as_null_object }
      let(:config) do
        {
            'server_url' => "https://k8s.example.com",
            'project'    => 'MyCoolProject',
            'namespace'  => 'backend',
            'access_key' => 'access_key',
            'secret_key' => 'secret_key',
            'services'   => %w[web worker]
        }
      end
      before { allow(subject).to receive(:environments).and_return('some' => config) }
      before { allow(subject).to receive(:image_name).and_return('image:tag') }
      before { allow(subject).to receive(:shell).and_return(shell) }

      it 'should login to rancher sending echo_1 command' do
        expect(shell).to receive(:run).with(
            'rancher login', 'https://k8s.example.com', '-t', 'access_key:secret_key', nil,
            in: an_instance_of(StringIO), only_output_on_error: true
        )
        subject.deploy!
      end

      context 'with login_options' do
        let(:config) do
          {
              'server_url'    => "https://k8s.example.com",
              'project'       => 'MyCoolProject',
              'namespace'     => 'backend',
              'access_key'    => 'access_key',
              'secret_key'    => 'secret_key',
              'services'      => %w[web worker],
              'login_options' => '--skip-verify'
          }
        end

        it 'should apply them to login command' do
          expect(shell).to receive(:run).with(
              'rancher login', 'https://k8s.example.com', '-t', 'access_key:secret_key', '--skip-verify',
              in: an_instance_of(StringIO), only_output_on_error: true
          )
          subject.deploy!
        end
      end

      it 'should switch context to given project' do
        expect(shell).to receive(:run).with('rancher', 'context', 'switch', config['project'])
        subject.deploy!
      end

      it 'should update individual services' do
        expect(shell).to receive(:run).with(
            'rancher kubectl set image deployment web web=image:tag',
            '-n', 'backend'
        )
        expect(shell).to receive(:run).with(
            'rancher kubectl set image deployment worker worker=image:tag',
            '-n', 'backend'
        )
        subject.deploy!
      end

      context 'with kubectl options' do
        let(:config) do
          {
              'server_url'      => "https://k8s.example.com",
              'project'         => 'MyCoolProject',
              'namespace'       => 'backend',
              'access_key'      => 'access_key',
              'secret_key'      => 'secret_key',
              'services'        => %w[web worker],
              'kubectl_options' => '--insecure-skip-tls-verify'
          }
        end

        it 'should update individual services' do
          expect(shell).to receive(:run).with(
              'rancher kubectl set image deployment web web=image:tag --insecure-skip-tls-verify',
              '-n', 'backend'
          )
          expect(shell).to receive(:run).with(
              'rancher kubectl set image deployment worker worker=image:tag --insecure-skip-tls-verify',
              '-n', 'backend'
          )
          subject.deploy!
        end
      end
    end
  end

  describe '#image_name' do
    let(:env_name) { 'some-env' }
    context 'when set in config' do
      let(:env_config) { {'image' => 'some:latest'} }
      it 'should return that value' do
        expect(subject.image_name(env_config, env_name)).to eq('some:latest')
      end
    end

    context 'when not set' do
      let(:env_config) { Hash.new }
      before { stub_env 'DRONE_REPO', 'fabn/example' }
      before { stub_env 'DRONE_COMMIT_SHA', '1234567890' }
      before { stub_env 'DRONE_SOURCE_BRANCH', 'develop' }
      it 'should build from ENV variables' do
        expect(subject.image_name(env_config, env_name)).to eq('fabn/example:drone-develop-12345678')
      end

      context 'when repo contains uppercase chars' do
        before { stub_env 'DRONE_REPO', 'fabn/Example' }
        it 'should downcase them' do
          expect(subject.image_name(env_config, env_name)).to start_with('fabn/example')
        end
      end

      context 'when branch contains slashes' do
        before { stub_env 'DRONE_SOURCE_BRANCH', 'feature/foo' }
        it 'should remove from tag name' do
          expect(subject.image_name(env_config, env_name)).to include('feature-foo')
        end
      end
    end
  end

  describe '#dry_run?' do
    context 'default value' do
      it { expect(subject.dry_run?).to be_falsey }
    end
    context 'when PLUGIN_DRY_RUN is present' do
      before { stub_env 'PLUGIN_DRY_RUN', 'anything' }
      it { expect(subject.dry_run?).to be_truthy }
    end
  end

  describe '#color?' do
    context 'default value' do
      it { expect(subject.color?).to be_truthy }
    end
    context 'when PLUGIN_COLORS is literal false' do
      before { stub_env 'PLUGIN_COLORS', 'false' }
      it { expect(subject.color?).to be_falsey }
    end
  end

  describe '#on_tag?' do

    context 'when env variabile is nil' do
      it do
        expect(ENV['DRONE_TAG']).to be_nil
        expect(subject.on_tag?).to be_falsey
      end
    end

    context 'when on tag' do
      before { stub_env 'DRONE_TAG', 'v1.2.3' }
      it 'should be truthy' do
        expect(subject.on_tag?).to be_truthy
      end
    end
  end
end