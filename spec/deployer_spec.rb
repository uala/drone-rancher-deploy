RSpec.describe RancherDeployer::Deployer do
  before { stub_env 'PLUGIN_LOGGING', 'error' }

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

  describe '#image_name' do
    context 'when set in config' do
      before { allow(subject).to receive(:config).and_return('image' => 'some:latest') }
      it 'should return that value' do
        expect(subject.image_name).to eq('some:latest')
      end
    end

    context 'when not set' do
      before { stub_env 'DRONE_REPO', 'fabn/example' }
      before { stub_env 'DRONE_COMMIT_SHA', '1234567890' }
      before { stub_env 'DRONE_SOURCE_BRANCH', 'develop' }
      it 'should build from ENV variables' do
        expect(subject.image_name).to eq('fabn/example:drone-develop-12345678')
      end

      context 'when repo contains uppercase chars' do
        before { stub_env 'DRONE_REPO', 'fabn/Example' }
        it 'should downcase them' do
          expect(subject.image_name).to start_with('fabn/example')
        end
      end

      context 'when branch contains slashes' do
        before { stub_env 'DRONE_SOURCE_BRANCH', 'feature/foo' }
        it 'should remove from tag name' do
          expect(subject.image_name).to include('feature-foo')
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