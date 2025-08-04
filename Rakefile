# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

# Default task
task default: :spec

# RSpec tasks
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = [
    '--color',
    '--format documentation',
    '--require spec_helper'
  ]
end

# Unit tests only
RSpec::Core::RakeTask.new('spec:unit') do |t|
  t.pattern = 'spec/lib/**/*_spec.rb'
  t.rspec_opts = [
    '--color',
    '--format documentation',
    '--require spec_helper'
  ]
end

# Integration tests only
RSpec::Core::RakeTask.new('spec:integration') do |t|
  t.pattern = 'spec/integration/**/*_spec.rb'
  t.rspec_opts = [
    '--color',
    '--format documentation',
    '--require spec_helper'
  ]
end

# Run tests with coverage
RSpec::Core::RakeTask.new('spec:coverage') do |t|
  ENV['COVERAGE'] = 'true'
  t.rspec_opts = [
    '--color',
    '--format documentation',
    '--require spec_helper'
  ]
end

# Fast tests (skip integration tests that might be slow)
RSpec::Core::RakeTask.new('spec:fast') do |t|
  t.pattern = 'spec/lib/**/*_spec.rb'
  t.rspec_opts = [
    '--color',
    '--format progress',
    '--require spec_helper'
  ]
end

# CI-friendly test runner
RSpec::Core::RakeTask.new('spec:ci') do |t|
  ENV['COVERAGE'] = 'true'
  t.rspec_opts = [
    '--color',
    '--format progress',
    '--format RSpec::Core::Formatters::JUnitFormatter',
    '--out tmp/rspec_results.xml',
    '--require spec_helper'
  ]
end

namespace :test do
  desc 'Run all tests with verbose output'
  task :verbose do
    ENV['VERBOSE'] = 'true'
    Rake::Task['spec'].invoke
  end

  desc 'Run tests and generate coverage report'
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task['spec'].invoke
    puts "\nCoverage report generated in coverage/"
  end

  desc 'Run only failing tests'
  task :failures do
    system('rspec --only-failures')
  end

  desc 'Run tests and watch for changes'
  task :watch do
    puts 'Watching for changes... (Press Ctrl+C to stop)'
    system('rspec --only-failures --next-failure')
  end
end

# Linting tasks
begin
  require 'rubocop/rake_task'
  
  RuboCop::RakeTask.new(:rubocop) do |t|
    t.options = ['--display-cop-names']
  end

  RuboCop::RakeTask.new('rubocop:auto_correct') do |t|
    t.options = ['--auto-correct']
  end

  # Combined quality task
  task :quality => [:rubocop, :spec]
  
rescue LoadError
  # RuboCop not available
  task :rubocop do
    puts 'RuboCop not available. Install with: gem install rubocop'
  end
  
  task :quality => :spec
end

# Documentation tasks
namespace :doc do
  desc 'Generate YARD documentation'
  task :generate do
    system('yard doc')
  end

  desc 'Serve documentation'
  task :serve do
    system('yard server --reload')
  end
end

# Setup tasks
namespace :setup do
  desc 'Install dependencies'
  task :deps do
    system('bundle install')
  end

  desc 'Setup development environment'
  task :dev => :deps do
    puts 'Creating necessary directories...'
    FileUtils.mkdir_p('tmp')
    FileUtils.mkdir_p('log')
    FileUtils.mkdir_p('coverage')
    puts 'Development environment ready!'
  end
end

# Clean up tasks
namespace :clean do
  desc 'Clean coverage reports'
  task :coverage do
    FileUtils.rm_rf('coverage')
  end

  desc 'Clean temporary files'
  task :tmp do
    FileUtils.rm_rf('tmp')
  end

  desc 'Clean all generated files'
  task :all => [:coverage, :tmp] do
    FileUtils.rm_rf('log')
    FileUtils.rm_rf('.yardoc')
    puts 'All generated files cleaned!'
  end
end

# Development helper tasks
namespace :dev do
  desc 'Open console with library loaded'
  task :console do
    require_relative 'lib/text_block_importer'
    require 'irb'
    IRB.start
  end

  desc 'Run tests in debug mode'
  task :debug do
    ENV['DEBUG'] = 'true'
    Rake::Task['spec'].invoke
  end
end

# Statistics tasks
namespace :stats do
  desc 'Show code statistics'
  task :loc do
    puts 'Lines of Code Statistics:'
    puts '========================'
    
    lib_files = Dir['lib/**/*.rb']
    spec_files = Dir['spec/**/*.rb']
    
    lib_lines = lib_files.sum { |f| File.readlines(f).size }
    spec_lines = spec_files.sum { |f| File.readlines(f).size }
    
    puts "Library code: #{lib_lines} lines in #{lib_files.size} files"
    puts "Test code: #{spec_lines} lines in #{spec_files.size} files"
    puts "Test coverage ratio: #{(spec_lines.to_f / lib_lines * 100).round(1)}%"
  end

  desc 'Show test statistics'
  task :tests do
    output = `rspec --dry-run --format json`
    data = JSON.parse(output)
    
    puts 'Test Statistics:'
    puts '==============='
    puts "Total examples: #{data['summary']['example_count']}"
    puts "Test files: #{Dir['spec/**/*_spec.rb'].size}"
    
    examples_by_file = data['examples'].group_by { |e| e['file_path'] }
    examples_by_file.each do |file, examples|
      puts "#{file}: #{examples.size} examples"
    end
  end
end

# Verification tasks
namespace :verify do
  desc 'Verify all dependencies are installed'
  task :deps do
    puts 'Checking dependencies...'
    
    required_gems = %w[nokogiri rspec webmock]
    missing_gems = []
    
    required_gems.each do |gem_name|
      begin
        require gem_name
        puts "✓ #{gem_name}"
      rescue LoadError
        puts "✗ #{gem_name} (missing)"
        missing_gems << gem_name
      end
    end
    
    if missing_gems.empty?
      puts 'All dependencies available!'
    else
      puts "Missing dependencies: #{missing_gems.join(', ')}"
      puts 'Run: bundle install'
      exit 1
    end
  end

  desc 'Verify test environment'
  task :env => :deps do
    puts 'Verifying test environment...'
    
    # Check for required directories
    required_dirs = %w[spec/lib spec/fixtures spec/support]
    required_dirs.each do |dir|
      if Dir.exist?(dir)
        puts "✓ #{dir}"
      else
        puts "✗ #{dir} (missing)"
      end
    end
    
    # Check for fixture files
    required_fixtures = %w[sample_page.html test_template.yml sample_sitemap.xml]
    required_fixtures.each do |fixture|
      path = "spec/fixtures/#{fixture}"
      if File.exist?(path)
        puts "✓ #{fixture}"
      else
        puts "✗ #{fixture} (missing)"
      end
    end
    
    puts 'Test environment verification complete!'
  end
end

# Help task
desc 'Show available tasks'
task :help do
  puts 'Available Rake Tasks:'
  puts '===================='
  puts
  puts 'Testing:'
  puts '  rake spec              - Run all tests'
  puts '  rake spec:unit         - Run unit tests only'
  puts '  rake spec:integration  - Run integration tests only'
  puts '  rake spec:fast         - Run fast tests (unit tests with progress format)'
  puts '  rake spec:ci           - Run tests with CI-friendly output'
  puts '  rake test:coverage     - Run tests with coverage report'
  puts '  rake test:verbose      - Run tests with verbose output'
  puts
  puts 'Quality:'
  puts '  rake rubocop           - Run RuboCop linter'
  puts '  rake quality           - Run both tests and linting'
  puts
  puts 'Development:'
  puts '  rake dev:console       - Open console with library loaded'
  puts '  rake dev:debug         - Run tests in debug mode'
  puts '  rake setup:dev         - Setup development environment'
  puts
  puts 'Maintenance:'
  puts '  rake clean:all         - Clean all generated files'
  puts '  rake stats:loc         - Show lines of code statistics'
  puts '  rake verify:env        - Verify test environment'
  puts
  puts 'Default: rake (runs all tests)'
end