require 'spec_helper'
require 'pdk/util/changelog_generator'

describe PDK::Util::ChangelogGenerator do
  describe '#generate_changelog' do
    let(:command) { double(PDK::CLI::Exec::InteractiveCommand, :context= => nil) } # rubocop:disable RSpec/VerifiedDoubles
    let(:command_stdout) { 'Success' }
    let(:command_exit_code) { 0 }
    let(:changelog_content) { 'foo' }

    before(:each) do
      allow(described_class).to receive(:github_changelog_generator_available!)
      allow(described_class).to receive(:changelog_content).and_return(changelog_content)
      expect(PDK::CLI::Exec::InteractiveCommand).to receive(:new).and_return(command)
      expect(command).to receive(:execute!).and_return(stdout: command_stdout, exit_code: command_exit_code)
    end

    it 'returns the changelog content' do
      expect(described_class.generate_changelog).to eq(changelog_content)
    end

    it 'executes the command in the context of the module' do
      expect(command).to receive(:context=).with(:module)
      described_class.generate_changelog
    end

    context 'when the changelog task retruns a non-zero exit code' do
      let(:command_exit_code) { 1 }

      it 'raises' do
        expect { described_class.generate_changelog }.to raise_error(PDK::CLI::ExitWithError, %r{#{command_stdout}})
      end
    end

    context 'with uncategorized Pull Requests' do
      let(:changelog_content) { 'UNCATEGORIZED PRS; GO LABEL THEM' }

      it 'raises' do
        expect { described_class.generate_changelog }.to raise_error(PDK::CLI::ExitWithError, %r{uncategorized Pull Requests})
      end
    end
  end

  describe '#compute_next_version' do
    context 'given invalid starting version' do
      [
        '1.x',
        '1',
        'a.b.c',
      ].each do |testcase|
        it "raises for #{testcase}" do
          expect { described_class.compute_next_version(testcase) }.to raise_error(StandardError)
        end
      end
    end

    context 'given a valid changelog' do
      let(:changelog_content) { '' }
      let(:current_version) { '1.2.3' }

      before(:each) do
        allow(described_class).to receive(:changelog_content).and_return(changelog_content)
      end

      context 'given a major change' do
        let(:changelog_content) do
          <<-EOT
          # Change log

          All notable changes to this project will be documented in this file.

          ## [v4.0.0](url_4.0)

          [Full Changelog](someting)

          ### Changed

          - something major

          ### Added

          - something minor

          ### Fixed

          - something tiny

          ## [v3.1.0](https://github.com/puppetlabs/puppetlabs-inifile/tree/v3.

          ## [v3.1.0](url_3.1)

          [Full Changelog](someting)

          ### Changed

          - something major

          ### Added

          - something minor

          ### Fixed

          - something tiny
          EOT
        end

        it 'returns a new major version' do
          expect(described_class.compute_next_version(current_version)).to eq('2.0.0')
        end
      end

      context 'given a minor change' do
        let(:changelog_content) do
          <<-EOT
          # Change log

          All notable changes to this project will be documented in this file.

          ## [v4.0.0](url_4.0)

          [Full Changelog](someting)

          ### Added

          - something minor

          ### Fixed

          - something tiny

          ## [v3.1.0](https://github.com/puppetlabs/puppetlabs-inifile/tree/v3.

          ## [v3.1.0](url_3.1)

          [Full Changelog](someting)

          ### Changed

          - something major

          ### Added

          - something minor

          ### Fixed

          - something tiny
          EOT
        end

        it 'returns a new minor version' do
          expect(described_class.compute_next_version(current_version)).to eq('1.3.0')
        end
      end

      context 'given a patch change' do
        let(:changelog_content) do
          <<-EOT
          # Change log

          All notable changes to this project will be documented in this file.

          ## [v4.0.0](url_4.0)

          [Full Changelog](someting)

          ### Fixed

          - something tiny

          ## [v3.1.0](https://github.com/puppetlabs/puppetlabs-inifile/tree/v3.

          ## [v3.1.0](url_3.1)

          [Full Changelog](someting)

          ### Changed

          - something major

          ### Added

          - something minor

          ### Fixed

          - something tiny
          EOT
        end

        it 'returns a new patch version' do
          expect(described_class.compute_next_version(current_version)).to eq('1.2.4')
        end
      end
    end
  end

  describe '.github_changelog_generator_available!' do
    subject(:method) { described_class.github_changelog_generator_available! }

    let(:command) { double(PDK::CLI::Exec::InteractiveCommand, :context= => nil) } # rubocop:disable RSpec/VerifiedDoubles

    before(:each) do
      expect(PDK::CLI::Exec::InteractiveCommand).to receive(:new).and_return(command)
    end

    context 'when the gem is available to Bundler' do
      let(:command_stdout) { '/path/to/gems/github_changelog_generator-1.15.2' }
      let(:command_exit_code) { 0 }

      before(:each) do
        expect(command).to receive(:execute!).and_return(stdout: command_stdout, exit_code: command_exit_code)
      end

      it 'does not raise an error' do
        expect { method }.not_to raise_error
      end
    end

    context 'when the gem is not available to Bundler' do
      let(:command_stderr) { 'Could not find gem \'github_changelog_generator\'.' }
      let(:command_exit_code) { 7 }

      before(:each) do
        expect(command).to receive(:execute!).and_return(stderr: command_stderr, exit_code: command_exit_code)
      end

      it 'raises an error' do
        expect { method }.to raise_error(PDK::CLI::ExitWithError, %r{not included})
      end
    end
  end
end
