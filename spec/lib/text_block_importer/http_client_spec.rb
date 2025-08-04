# frozen_string_literal: true

require 'spec_helper'
require 'net/http'

RSpec.describe TextBlockImporter::HttpClient do
  let(:config) { mock_config }
  let(:logger) { double('Logger', debug: nil, warn: nil, info: nil) }

  subject { described_class.new(config, logger) }

  describe '#initialize' do
    it 'creates a new instance with config and logger' do
      client = described_class.new(config, logger)
      expect(client).to be_an_instance_of(described_class)
    end

    it 'works without logger' do
      client = described_class.new(config)
      expect(client).to be_an_instance_of(described_class)
    end
  end

  describe '#fetch' do
    let(:url) { 'https://example.com/page' }
    let(:uri) { URI.parse(url) }
    let(:response_body) { '<html><body>Test content</body></html>' }

    context 'with successful HTTP request' do
      let(:successful_response) do
        instance_double(Net::HTTPSuccess, code: '200', body: response_body)
      end

      before do
        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(successful_response)
      end

      it 'returns response body' do
        result = subject.fetch(url)
        expect(result).to eq(response_body)
      end

      it 'logs debug information' do
        expect(logger).to receive(:debug).with("Fetching URL: #{url}")
        expect(logger).to receive(:debug).with('Response status: 200')

        subject.fetch(url)
      end

      it 'parses URL correctly' do
        expect(URI).to receive(:parse).with(url).and_return(uri)
        expect(Net::HTTP).to receive(:get_response).with(uri)

        subject.fetch(url)
      end
    end

    context 'with redirect responses when follow_redirects is enabled' do
      let(:config_with_redirects) do
        mock_config('http' => { 'follow_redirects' => true })
      end
      let(:redirect_response) do
        instance_double(Net::HTTPMovedPermanently, 
                       code: '301', 
                       '[]' => 'https://example.com/new-location').tap do |response|
          allow(response).to receive(:[]).with('location').and_return('https://example.com/new-location')
          allow(response).to receive(:is_a?).with(Net::HTTPMovedPermanently).and_return(true)
        end
      end
      let(:final_response) do
        instance_double(Net::HTTPSuccess, code: '200', body: response_body)
      end
      let(:redirect_uri) { URI.parse('https://example.com/new-location') }

      subject { described_class.new(config_with_redirects, logger) }

      before do
        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(redirect_response)
        allow(Net::HTTP).to receive(:get_response).with(redirect_uri).and_return(final_response)
        allow(URI).to receive(:parse).with(url).and_return(uri)
        allow(URI).to receive(:parse).with('https://example.com/new-location').and_return(redirect_uri)
      end

      it 'follows redirects and returns final response body' do
        result = subject.fetch(url)
        expect(result).to eq(response_body)
      end

      it 'makes two HTTP requests for redirect' do
        subject.fetch(url)
        
        expect(Net::HTTP).to have_received(:get_response).with(uri).once
        expect(Net::HTTP).to have_received(:get_response).with(redirect_uri).once
      end
    end

    context 'when follow_redirects is disabled' do
      let(:config_no_redirects) do
        mock_config('http' => { 'follow_redirects' => false })
      end
      let(:redirect_response) do
        instance_double(Net::HTTPMovedPermanently, 
                       code: '301', 
                       body: 'Moved Permanently')
      end

      subject { described_class.new(config_no_redirects, logger) }

      before do
        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(redirect_response)
      end

      it 'returns redirect response without following' do
        result = subject.fetch(url)
        expect(result).to eq('Moved Permanently')
      end

      it 'makes only one HTTP request' do
        subject.fetch(url)
        expect(Net::HTTP).to have_received(:get_response).with(uri).once
      end
    end

    context 'with network errors and retries' do
      let(:config_with_retries) do
        mock_config('http' => { 'retries' => 2 })
      end
      let(:network_error) { StandardError.new('Connection refused') }

      subject { described_class.new(config_with_retries, logger) }

      context 'when all attempts fail' do
        before do
          allow(Net::HTTP).to receive(:get_response).with(uri).and_raise(network_error)
        end

        it 'raises NetworkError after exhausting retries' do
          expect { subject.fetch(url) }
            .to raise_error(TextBlockImporter::NetworkError, 
                          /Failed to fetch #{Regexp.escape(url)} after 2 retries: Connection refused/)
        end

        it 'attempts the configured number of retries' do
          expect { subject.fetch(url) }.to raise_error(TextBlockImporter::NetworkError)
          
          # Initial attempt + 2 retries = 3 total attempts
          expect(Net::HTTP).to have_received(:get_response).with(uri).exactly(3).times
        end

        it 'logs retry attempts' do
          expect(logger).to receive(:warn).with(/Fetch attempt \d+ failed: Connection refused/).exactly(3).times
          expect(logger).to receive(:info).with(/Retrying... \(\d+\/2\)/).exactly(2).times

          expect { subject.fetch(url) }.to raise_error(TextBlockImporter::NetworkError)
        end
      end

      context 'when retry succeeds' do
        let(:successful_response) do
          instance_double(Net::HTTPSuccess, code: '200', body: response_body)
        end

        before do
          call_count = 0
          allow(Net::HTTP).to receive(:get_response).with(uri) do
            call_count += 1
            if call_count < 3
              raise network_error
            else
              successful_response
            end
          end
        end

        it 'returns successful response after retries' do
          result = subject.fetch(url)
          expect(result).to eq(response_body)
        end

        it 'logs successful retry' do
          expect(logger).to receive(:warn).with(/Fetch attempt \d+ failed/).exactly(2).times
          expect(logger).to receive(:info).with(/Retrying.../).exactly(2).times

          subject.fetch(url)
        end
      end
    end

    context 'with zero retries configured' do
      let(:config_no_retries) do
        mock_config('http' => { 'retries' => 0 })
      end
      let(:network_error) { StandardError.new('Connection refused') }

      subject { described_class.new(config_no_retries, logger) }

      before do
        allow(Net::HTTP).to receive(:get_response).with(uri).and_raise(network_error)
      end

      it 'fails immediately without retries' do
        expect { subject.fetch(url) }
          .to raise_error(TextBlockImporter::NetworkError, 
                        /Failed to fetch #{Regexp.escape(url)} after 0 retries/)
      end

      it 'makes only one attempt' do
        expect { subject.fetch(url) }.to raise_error(TextBlockImporter::NetworkError)
        expect(Net::HTTP).to have_received(:get_response).with(uri).once
      end
    end

    context 'with different types of HTTP errors' do
      let(:timeout_error) { Net::ReadTimeout.new('Request timeout') }
      let(:socket_error) { SocketError.new('Host not found') }
      let(:connection_error) { Errno::ECONNREFUSED.new('Connection refused') }

      before do
        allow(config).to receive(:retries).and_return(1)
      end

      it 'handles timeout errors' do
        allow(Net::HTTP).to receive(:get_response).with(uri).and_raise(timeout_error)

        expect { subject.fetch(url) }
          .to raise_error(TextBlockImporter::NetworkError, /Request timeout/)
      end

      it 'handles socket errors' do
        allow(Net::HTTP).to receive(:get_response).with(uri).and_raise(socket_error)

        expect { subject.fetch(url) }
          .to raise_error(TextBlockImporter::NetworkError, /Host not found/)
      end

      it 'handles connection refused errors' do
        allow(Net::HTTP).to receive(:get_response).with(uri).and_raise(connection_error)

        expect { subject.fetch(url) }
          .to raise_error(TextBlockImporter::NetworkError, /Connection refused/)
      end
    end

    context 'with various URL formats' do
      it 'handles HTTP URLs' do
        http_url = 'http://example.com/page'
        http_uri = URI.parse(http_url)
        response = instance_double(Net::HTTPSuccess, code: '200', body: 'content')

        allow(Net::HTTP).to receive(:get_response).with(http_uri).and_return(response)

        result = subject.fetch(http_url)
        expect(result).to eq('content')
      end

      it 'handles URLs with query parameters' do
        query_url = 'https://example.com/page?param=value&other=test'
        query_uri = URI.parse(query_url)
        response = instance_double(Net::HTTPSuccess, code: '200', body: 'content')

        allow(Net::HTTP).to receive(:get_response).with(query_uri).and_return(response)

        result = subject.fetch(query_url)
        expect(result).to eq('content')
      end

      it 'handles URLs with fragments' do
        fragment_url = 'https://example.com/page#section'
        fragment_uri = URI.parse(fragment_url)
        response = instance_double(Net::HTTPSuccess, code: '200', body: 'content')

        allow(Net::HTTP).to receive(:get_response).with(fragment_uri).and_return(response)

        result = subject.fetch(fragment_url)
        expect(result).to eq('content')
      end

      it 'handles URLs with special characters' do
        special_url = 'https://example.com/encoded%20path'
        special_uri = URI.parse(special_url)
        response = instance_double(Net::HTTPSuccess, code: '200', body: 'content')

        allow(Net::HTTP).to receive(:get_response).with(special_uri).and_return(response)

        result = subject.fetch(special_url)
        expect(result).to eq('content')
      end
    end

    context 'with invalid URLs' do
      it 'raises error for malformed URLs' do
        invalid_url = 'not-a-valid-url'

        expect { subject.fetch(invalid_url) }
          .to raise_error(TextBlockImporter::NetworkError, /(not an HTTP URI|missing hierarchical segment)/)
      end

      it 'raises error for unsupported schemes' do
        ftp_url = 'ftp://example.com/file'
        ftp_uri = URI.parse(ftp_url)
        
        # Mock Net::HTTP to raise an error for FTP URLs
        allow(Net::HTTP).to receive(:get_response).with(ftp_uri).and_raise(StandardError.new('Unsupported scheme'))

        expect { subject.fetch(ftp_url) }
          .to raise_error(TextBlockImporter::NetworkError, /Unsupported scheme/)
      end
    end

    context 'with different response types' do
      it 'handles empty response bodies' do
        empty_response = instance_double(Net::HTTPSuccess, code: '200', body: '')
        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(empty_response)

        result = subject.fetch(url)
        expect(result).to eq('')
      end

      it 'handles large response bodies' do
        large_body = 'x' * 1_000_000 # 1MB of content
        large_response = instance_double(Net::HTTPSuccess, code: '200', body: large_body)
        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(large_response)

        result = subject.fetch(url)
        expect(result).to eq(large_body)
      end

      it 'handles binary content' do
        binary_content = "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR" # PNG header
        binary_response = instance_double(Net::HTTPSuccess, code: '200', body: binary_content)
        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(binary_response)

        result = subject.fetch(url)
        expect(result).to eq(binary_content)
      end
    end

    context 'with complex redirect scenarios' do
      let(:config_with_redirects) do
        mock_config('http' => { 'follow_redirects' => true })
      end

      subject { described_class.new(config_with_redirects, logger) }

      it 'handles redirect to different domain' do
        redirect_response = instance_double(Net::HTTPMovedPermanently,
                                          code: '301', 
                                          body: 'redirect body')
        allow(redirect_response).to receive(:[]).with('location').and_return('https://newdomain.com/page')
        allow(redirect_response).to receive(:is_a?).with(Net::HTTPMovedPermanently).and_return(true)
        
        final_response = instance_double(Net::HTTPSuccess, code: '200', body: 'redirected content')
        redirect_uri = URI.parse('https://newdomain.com/page')

        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(redirect_response)
        allow(Net::HTTP).to receive(:get_response).with(redirect_uri).and_return(final_response)
        allow(URI).to receive(:parse).with(url).and_return(uri)
        allow(URI).to receive(:parse).with('https://newdomain.com/page').and_return(redirect_uri)

        result = subject.fetch(url)
        expect(result).to eq('redirected content')
      end

      it 'handles relative redirect URLs' do
        redirect_response = instance_double(Net::HTTPMovedPermanently,
                                          code: '301',
                                          body: 'redirect body')
        allow(redirect_response).to receive(:[]).with('location').and_return('/new-path')
        allow(redirect_response).to receive(:is_a?).with(Net::HTTPMovedPermanently).and_return(true)
        
        final_response = instance_double(Net::HTTPSuccess, code: '200', body: 'redirected content')
        # Note: This test assumes the redirect handling converts relative to absolute URLs
        relative_uri = URI.parse('/new-path')

        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(redirect_response)
        allow(Net::HTTP).to receive(:get_response).with(relative_uri).and_return(final_response)
        allow(URI).to receive(:parse).with(url).and_return(uri)
        allow(URI).to receive(:parse).with('/new-path').and_return(relative_uri)

        result = subject.fetch(url)
        expect(result).to eq('redirected content')
      end
    end

    context 'without logger' do
      subject { described_class.new(config) }

      it 'works without logger for successful requests' do
        successful_response = instance_double(Net::HTTPSuccess, code: '200', body: response_body)
        allow(Net::HTTP).to receive(:get_response).with(uri).and_return(successful_response)

        result = subject.fetch(url)
        expect(result).to eq(response_body)
      end

      it 'works without logger for failed requests' do
        allow(Net::HTTP).to receive(:get_response).with(uri).and_raise(StandardError.new('Error'))

        expect { subject.fetch(url) }
          .to raise_error(TextBlockImporter::NetworkError)
      end
    end
  end

  describe 'private methods' do
    describe '#handle_redirects' do
      let(:config_with_redirects) do
        mock_config('http' => { 'follow_redirects' => true })
      end

      subject { described_class.new(config_with_redirects, logger) }

      # Testing private methods through public interface
      context 'redirect handling behavior' do
        it 'only handles permanent redirects (301)' do
          # Test that only 301 redirects are followed through public interface
          temp_redirect = instance_double(Net::HTTPFound, code: '302', body: 'temporary')
          uri = URI.parse('https://example.com/page')

          allow(Net::HTTP).to receive(:get_response).with(uri).and_return(temp_redirect)

          result = subject.fetch('https://example.com/page')
          expect(result).to eq('temporary') # Should return original response, not follow redirect
        end
      end
    end
  end
end