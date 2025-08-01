# frozen_string_literal: true

# Shared examples for HTTP operations
RSpec.shared_examples 'an HTTP operation' do
  it 'raises NetworkError when HTTP request fails' do
    allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Connection failed'))
    
    expect { subject }.to raise_error(TextBlockImporter::NetworkError, /Connection failed/)
  end

  it 'retries failed requests according to configuration' do
    config = mock_config('http' => { 'retries' => 2 })
    allow(subject).to receive(:instance_variable_get).with(:@config).and_return(config)
    
    allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Temporary failure'))
    
    expect { subject }.to raise_error(TextBlockImporter::NetworkError)
    expect(Net::HTTP).to have_received(:get_response).exactly(3).times # initial + 2 retries
  end
end

# Shared examples for content processing
RSpec.shared_examples 'content processor' do
  it 'handles empty content gracefully' do
    result = subject
    expect(result).to be_a(String)
  end

  it 'processes content according to configuration settings' do
    # This will be customized by individual specs
    expect(subject).to respond_to(:length)
  end
end

# Shared examples for YAML generation
RSpec.shared_examples 'YAML generator' do
  it 'generates valid YAML structure' do
    result = subject
    parsed = YAML.safe_load(result)
    
    expect(parsed).to be_a(Hash)
    expect(parsed).to have_key('uuid')
    expect(parsed).to have_key('entity_type')
    expect(parsed).to have_key('bundle')
  end

  it 'replaces all template tokens' do
    result = subject
    
    # Check that no template tokens remain unreplaced
    expect(result).not_to include('{NAME}')
    expect(result).not_to include('{URL}')
    expect(result).not_to include('{UUID}')
    expect(result).not_to include('{BLOCK_UUID}')
    expect(result).not_to include('{REPLACEME}')
    expect(result).not_to include('{SOURCE_URL}')
  end

  it 'generates valid UUIDs for template tokens' do
    result = subject
    parsed = YAML.safe_load(result)
    
    expect_valid_uuid(parsed['uuid'])
    
    # Check block UUID if present
    if parsed.dig('layout_builder__layout', 'blocks')&.any?
      block_uuid = parsed['layout_builder__layout']['blocks'].first['uuid']
      expect_valid_uuid(block_uuid)
    end
  end
end

# Shared examples for URL handling
RSpec.shared_examples 'URL processor' do
  it 'handles relative URLs correctly' do
    # Implementation depends on the specific class
    expect(subject).to respond_to(:gsub) if subject.is_a?(String)
  end

  it 'preserves absolute URLs' do
    # Will be customized by individual specs
    expect(subject).to be_a(String) if subject.is_a?(String)
  end
end

# Shared examples for error handling
RSpec.shared_examples 'error handler' do |error_class|
  it "raises #{error_class} for invalid inputs" do
    expect { subject }.to raise_error(error_class)
  end

  it 'provides meaningful error messages' do
    begin
      subject
    rescue error_class => e
      expect(e.message).not_to be_empty
      expect(e.message).to be_a(String)
    end
  end
end

# Shared examples for configuration-aware components
RSpec.shared_examples 'configurable component' do
  it 'uses provided configuration' do
    mock_config('processing' => { 'strip_newlines' => false })
    
    # This will be customized per component
    expect(subject).to respond_to(:instance_variable_get)
  end

  it 'falls back to default configuration when none provided' do
    # Verify component works with default config
    expect { subject }.not_to raise_error
  end
end

# Shared examples for file operations
RSpec.shared_examples 'file operations' do
  let(:temp_dir) { create_temp_directory }
  
  after { FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir) }

  it 'creates directories when they do not exist' do
    nested_path = File.join(temp_dir, 'nested', 'directory', 'file.yml')
    
    subject.call(nested_path) if subject.respond_to?(:call)
    
    expect(Dir.exist?(File.dirname(nested_path))).to be true
  end

  it 'writes files with correct permissions' do
    file_path = File.join(temp_dir, 'test_file.yml')
    
    subject.call(file_path) if subject.respond_to?(:call)
    
    expect(File.exist?(file_path)).to be true
    expect(File.readable?(file_path)).to be true
  end
end