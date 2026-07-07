module Ai
  module Providers
    # OpenAI Chat Completions API. https://platform.openai.com/docs/api-reference/chat
    class Openai
      API_URL = "https://api.openai.com/v1/chat/completions".freeze

      def self.chat(model:, system:, user:, max_tokens: 1024)
        api_key = ENV["OPENAI_API_KEY"]
        raise Ai::NotConfigured, "OPENAI_API_KEY is not set" if api_key.blank?

        response = Faraday.post(API_URL) do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.headers["content-type"] = "application/json"
          req.options.timeout = 60
          req.body = {
            model: model,
            max_completion_tokens: max_tokens,
            messages: [
              { role: "system", content: system },
              { role: "user", content: user }
            ]
          }.to_json
        end

        body = JSON.parse(response.body) rescue {}
        if response.status >= 400
          message = body.dig("error", "message") || "HTTP #{response.status}"
          raise Ai::Error, "OpenAI API error: #{message}"
        end
        body.dig("choices", 0, "message", "content").to_s
      rescue Faraday::Error => e
        raise Ai::Error, "Could not reach the OpenAI API: #{e.message}"
      end
    end
  end
end
