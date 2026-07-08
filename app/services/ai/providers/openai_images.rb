module Ai
  module Providers
    # OpenAI Images API (gpt-image-1 family).
    # - generate: text -> image        POST /v1/images/generations
    # - edit:     image + text -> image POST /v1/images/edits (multipart)
    # Both return base64 PNG data; callers get the decoded binary.
    # https://platform.openai.com/docs/api-reference/images
    class OpenaiImages
      API_HOST = "https://api.openai.com".freeze
      TIMEOUT = 180 # image generation regularly takes 30-90s

      def self.generate(prompt:, model:, size:, quality:)
        body = request(:json, "/v1/images/generations",
          model: model, prompt: prompt, size: size, quality: quality, n: 1)
        decode_image(body)
      end

      def self.edit(image:, prompt:, model:, size:, quality:)
        # image is an ActionDispatch::Http::UploadedFile (or anything with
        # tempfile/original_filename/content_type).
        part = Faraday::Multipart::FilePart.new(
          image.tempfile.path, image.content_type, image.original_filename
        )
        body = request(:multipart, "/v1/images/edits",
          model: model, prompt: prompt, size: size, quality: quality, image: part)
        decode_image(body)
      end

      def self.request(kind, path, params)
        api_key = ENV["OPENAI_API_KEY"]
        raise Ai::NotConfigured, "OPENAI_API_KEY is not set" if api_key.blank?

        conn = Faraday.new(url: API_HOST) do |f|
          f.request :multipart if kind == :multipart
          f.request :url_encoded if kind == :multipart
          f.options.timeout = TIMEOUT
        end

        response = conn.post(path) do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          if kind == :json
            req.headers["content-type"] = "application/json"
            req.body = params.to_json
          else
            req.body = params
          end
        end

        body = JSON.parse(response.body) rescue {}
        if response.status >= 400
          message = body.dig("error", "message") || "HTTP #{response.status}"
          raise Ai::Error, "OpenAI Images API error: #{message}"
        end
        body
      rescue Faraday::Error => e
        raise Ai::Error, "Could not reach the OpenAI API: #{e.message}"
      end
      private_class_method :request

      def self.decode_image(body)
        b64 = body.dig("data", 0, "b64_json")
        raise Ai::Error, "OpenAI returned no image data" if b64.blank?
        Base64.decode64(b64)
      end
      private_class_method :decode_image
    end
  end
end
