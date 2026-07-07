module Ai
  module Providers
    # Anthropic Messages API. https://docs.anthropic.com/en/api/messages
    class Anthropic
      API_URL = "https://api.anthropic.com/v1/messages".freeze
      API_VERSION = "2023-06-01".freeze

      def self.chat(model:, system:, user:, max_tokens: 1024)
        api_key = ENV["ANTHROPIC_API_KEY"]
        raise Ai::NotConfigured, "ANTHROPIC_API_KEY is not set" if api_key.blank?

        response = Faraday.post(API_URL) do |req|
          req.headers["x-api-key"] = api_key
          req.headers["anthropic-version"] = API_VERSION
          req.headers["content-type"] = "application/json"
          req.options.timeout = 60
          req.body = {
            model: model,
            max_tokens: max_tokens,
            system: system,
            messages: [{ role: "user", content: user }]
          }.to_json
        end

        body = JSON.parse(response.body) rescue {}
        if response.status >= 400
          message = body.dig("error", "message") || "HTTP #{response.status}"
          raise Ai::Error, "Anthropic API error: #{message}"
        end
        body.dig("content", 0, "text").to_s
      rescue Faraday::Error => e
        raise Ai::Error, "Could not reach the Anthropic API: #{e.message}"
      end
    end
  end
end
