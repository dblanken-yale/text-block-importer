# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'CLI Executable Integration', type: :integration do
  let(:temp_dir) { create_temp_directory }
  let(:root_dir) { File.expand_path('../..', __dir__) }

  after do
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  describe 'text_block_importer executable' do
    let(:executable_path) { File.join(root_dir, 'text_block_importer') }

    before do
      skip 'Executable not found' unless File.exist?(executable_path)
      skip 'Executable not executable' unless File.executable?(executable_path)
    end

    it 'runs without arguments and shows help' do
      stdout, stderr, status = Open3.capture3(executable_path)
      
      # Most CLI tools show help or usage when run without arguments
      expect(status.success?).to be_falsy # Usually exits with non-zero for missing args
      expect(stdout + stderr).to match(/usage|help|error|invalid/i)
    end

    it 'shows version information when requested' do
      stdout, stderr, _status = Open3.capture3(executable_path, '--version')
      
      expect(stdout + stderr).to match(/\d+\.\d+\.\d+/)
    end

    it 'shows help when requested' do
      stdout, stderr, _status = Open3.capture3(executable_path, '--help')
      
      expect(stdout + stderr).to match(/usage|help|options/i)
    end
  end


  describe 'runtime dependencies' do
    it 'has ruby available for text_block_importer executable' do
      stdout, _stderr, status = Open3.capture3('which', 'ruby')
      
      expect(status.success?).to be true
      expect(stdout.strip).not_to be_empty
    end
  end


  describe 'file permissions and structure' do
    it 'has correct permissions on executable files' do
      executable_path = File.join(root_dir, 'text_block_importer')
      
      if File.exist?(executable_path)
        expect(File.executable?(executable_path)).to be true
        
        # Check that the file is not world-writable (security)
        mode = File.stat(executable_path).mode
        expect(mode & 0o002).to eq(0) # World-writable bit should not be set
      end
    end

    it 'has proper shebang line in text_block_importer executable' do
      executable_path = File.join(root_dir, 'text_block_importer')
      
      if File.exist?(executable_path)
        first_line = File.open(executable_path, &:readline).strip
        expect(first_line).to match(/^#!/)
        expect(first_line).to match(/ruby/)
      end
    end
  end
end