# frozen_string_literal: true

class ComgateService
  module HttpClient
    private

    def make_api_request(method, endpoint, payload = nil)
      uri = URI("#{BASE_URL}#{endpoint}")
      Rails.logger.info "Making Comgate API #{method} request to #{endpoint}"

      http = configure_http_client(uri)
      request = build_http_request(method, uri, payload)

      response = http.request(request)
      handle_http_response(response)
    rescue Net::TimeoutError, Net::OpenTimeout => e
      raise ApiError, "Network timeout: #{e.message}"
    rescue JSON::ParserError => e
      raise ApiError, "Invalid JSON response: #{e.message}"
    rescue StandardError => e
      raise ApiError, "Request failed: #{e.message}"
    end

    def configure_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10
      http
    end

    def build_http_request(method, uri, payload)
      request = create_http_request_object(method, uri)
      configure_request_auth(request)
      configure_request_payload(request, payload) if payload
      request
    end

    def create_http_request_object(method, uri)
      case method
      when 'GET'
        Net::HTTP::Get.new(uri)
      when 'POST'
        Net::HTTP::Post.new(uri)
      when 'DELETE'
        Net::HTTP::Delete.new(uri)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    def configure_request_auth(request)
      request.basic_auth(@merchant_id, @secret)
    end

    def configure_request_payload(request, payload)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json
    end

    def handle_http_response(response)
      raise ApiError, "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      parsed_response = JSON.parse(response.body)
      Rails.logger.debug { "Comgate response #{parsed_response.inspect}" }
      parsed_response
    end
  end
end
