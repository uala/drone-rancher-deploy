RSpec.describe RancherDeployer::TagChecker do
  before { stub_env 'PLUGIN_LOGGING', 'error' }
  before { allow(::Kernel).to receive(:exit) }

  describe '#check!' do
    context 'when not on tag' do
      it 'should pass' do
        expect(subject.check!).to be_truthy
      end
    end

    context 'when on tag' do
      before { stub_env 'DRONE_TAG', drone_tag }
      let(:drone_tag) { 'v1.2.3' }

      context 'when enforce_branch_for_tags is not given' do
        it 'should pass' do
          expect(subject.check!).to be_truthy
        end
      end

      context 'when enforce_branch_for_tags is set' do
        before { stub_env 'PLUGIN_ENFORCE_BRANCH_FOR_TAG', 'master' }

        it 'should check branch name' do
          expect(subject).to receive(:branches_for_tag).and_return(['master'])
          expect(subject.check!).to be_truthy
          expect(::Kernel).not_to have_received(:exit).with(1)
        end

        context 'with other branches' do
          it 'should exit with status code 1' do
            expect(subject).to receive(:branches_for_tag).and_return(['develop'])
            subject.check!
            expect(::Kernel).to have_received(:exit).with(1)
          end
        end

        context 'when enforce_head is set' do
          before { stub_env 'PLUGIN_ENFORCE_HEAD', 'true' }
          before { allow(subject).to receive(:branches_for_tag).and_return(['master']) }

          context 'when tag is on head' do
            it 'should not prevent deployments' do
              expect(subject).to receive(:tag_is_on_head?).with(drone_tag, 'master').and_return(true)
              expect(subject.check!).to be_truthy
              expect(::Kernel).not_to have_received(:exit).with(1)
            end
          end

          context 'when tag is not on head' do
            it 'should exit with status code 1' do
              expect(subject).to receive(:tag_is_on_head?).with(drone_tag, 'master').and_return(false)
              subject.check!
              expect(::Kernel).to have_received(:exit).with(1)
            end
          end
        end
      end
    end
  end

  describe '#branches_for_tag' do
    let(:tag) { 'demo-tag' }
    it 'should return branches that contains the given tag' do
      expect(subject.branches_for_tag(tag)).to include('master')
    end

    context 'with merged branches' do
      let(:tag) { '0b93b01' } # Works with any ref also plain commits
      it 'should return branches that contains the given tag' do
        expect(subject.branches_for_tag(tag)).to include('master')
      end
    end

    context 'when tagging outside of master' do
      let(:tag) { 'bad-tag' }
      it 'should not include master' do
        branches_for_bad_tag = subject.branches_for_tag(tag)
        expect(branches_for_bad_tag).not_to be_empty
        expect(branches_for_bad_tag).not_to include('master')
      end
    end

    context 'with remote only branches' do
      let(:tag) { 'only-remote' }
      it 'should include remote branches' do
        branches_for_remote_tag = subject.branches_for_tag(tag)
        expect(branches_for_remote_tag).not_to be_empty
        expect(branches_for_remote_tag).to include('remote-branch-only')
      end
    end
  end

  describe '#enforce_tag_on_branch?' do
    context 'when plugin option is not present' do
      it 'should be falsey' do
        expect(subject.enforce_tag_on_branch?).to be_falsey
      end
    end

    context 'when option is set' do
      before { stub_env 'PLUGIN_ENFORCE_BRANCH_FOR_TAG', 'master' }
      it 'should be falsey' do
        expect(subject.enforce_tag_on_branch?).to be_falsey
      end

      context 'when also on tag' do
        before { stub_env 'DRONE_TAG', 'v1.2.3' }
        it 'should be truthy' do
          expect(subject.enforce_tag_on_branch?).to be_truthy
        end
      end
    end
  end

  describe '#enforce_head?' do
    context 'when plugin option is not present' do
      it 'should be falsey' do
        expect(subject.enforce_head?).to be_falsey
      end
    end

    context 'when all options are set' do
      before { stub_env 'DRONE_TAG', 'v1.2.3' }
      before { stub_env 'PLUGIN_ENFORCE_BRANCH_FOR_TAG', 'master' }
      before { stub_env 'PLUGIN_ENFORCE_HEAD', 'true' }
      it 'should be truthy' do
        expect(subject.enforce_head?).to be_truthy
      end
    end
  end

  describe '#git_credentials' do
    let(:stubbed_file) { File.realpath("#{__dir__}/netrc.example") }
    before { FileUtils.chmod(0600, stubbed_file) }
    before { allow(subject).to receive(:credentials_file).and_return(stubbed_file) }

    it 'should parse netrc file' do
      credentials = subject.git_credentials
      expect(credentials).to be_an_instance_of(Netrc::Entry)
      expect(credentials.login).to match %r{^\h{40}$}
      expect(credentials.password).to eq('x-oauth-basic')
    end
  end
end