module Ai
  # Generates a social media caption (+ hashtags) from the user's instructions.
  # The provider and model are chosen globally on the AI settings screen
  # (AppSetting.current); the matching API key must be present in ENV.
  class CaptionGenerator
    def initialize(company:, instructions:, platforms: [], title: nil)
      @company = company
      @instructions = instructions.to_s.strip
      @platforms = Array(platforms).reject(&:blank?)
      @title = title.to_s.strip
      raise Ai::Error, "Instructions can't be blank" if @instructions.blank?
    end

    # Returns { caption: String, hashtags: String }
    def generate
      setting = AppSetting.current
      client = Ai::Providers.client_for(setting.ai_provider)
      text = client.chat(
        model: setting.ai_model_or_default,
        system: system_prompt,
        user: user_prompt
      )
      parse_result(text)
    end

    private

    def system_prompt
      <<~PROMPT
        You are a social media copywriter for the brand "#{@company.name}".
        Write engaging, natural-sounding captions. Avoid clichés and excessive emoji.
        Respond with ONLY a JSON object, no markdown fences, in this exact shape:
        {"caption": "the caption text", "hashtags": "#tag1 #tag2 #tag3"}
        The caption must NOT contain hashtags — put all hashtags in the hashtags field
        (5-10 relevant ones). Keep captions under 2,200 characters (Instagram's limit).
      PROMPT
    end

    def user_prompt
      parts = ["Write a caption based on these instructions:\n#{@instructions}"]
      parts << "Target platforms: #{@platforms.join(', ')}." if @platforms.any?
      parts << "Internal working title of the post: #{@title}." if @title.present?
      parts.join("\n\n")
    end

    def parse_result(text)
      json = JSON.parse(text.sub(/\A```(?:json)?/, "").sub(/```\z/, "").strip)
      { caption: json["caption"].to_s.strip, hashtags: json["hashtags"].to_s.strip }
    rescue JSON::ParserError
      # Model didn't return clean JSON — treat the whole reply as the caption.
      { caption: text.strip, hashtags: "" }
    end
  end
end
