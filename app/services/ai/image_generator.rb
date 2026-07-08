module Ai
  # Generates a social media image for a post, either from scratch (text ->
  # image) or by transforming an uploaded image into a flyer (image + text ->
  # image). Model and quality come from the global AI settings.
  #
  # The raw description/caption is first turned into a proper image prompt by
  # the configured text model; if no text provider is configured we fall back
  # to a hand-assembled prompt so image generation still works.
  class ImageGenerator
    SIZES = {
      "square"    => "1024x1024",
      "portrait"  => "1024x1536",
      "landscape" => "1536x1024"
    }.freeze

    def initialize(company:, mode:, description: nil, caption: nil, title: nil, size: "square", image: nil)
      @company = company
      @mode = mode == "enhance" ? "enhance" : "scratch"
      @description = description.to_s.strip
      @caption = caption.to_s.strip
      @title = title.to_s.strip
      @size = SIZES.fetch(size) { SIZES["square"] }
      @image = image

      if @mode == "enhance" && @image.blank?
        raise Ai::Error, "Upload an image to enhance first."
      end
      if @mode == "scratch" && @description.blank? && @caption.blank?
        raise Ai::Error, "Describe the image, or write a caption first so we can work from that."
      end
    end

    # Returns { png: <binary>, prompt: <the prompt actually used> }
    def generate
      setting = AppSetting.current
      prompt = build_prompt

      png =
        if @mode == "enhance"
          Ai::Providers::OpenaiImages.edit(
            image: @image, prompt: prompt,
            model: setting.image_model, size: @size, quality: setting.image_quality
          )
        else
          Ai::Providers::OpenaiImages.generate(
            prompt: prompt,
            model: setting.image_model, size: @size, quality: setting.image_quality
          )
        end

      { png: png, prompt: prompt }
    end

    private

    # Ask the configured text model to write a strong image prompt from the
    # user's note + post context. Falls back to a simple assembled prompt if
    # the text provider isn't configured or errors out.
    def build_prompt
      setting = AppSetting.current
      client = Ai::Providers.client_for(setting.ai_provider)
      client.chat(
        model: setting.ai_model_or_default,
        system: prompt_builder_system,
        user: prompt_builder_user,
        max_tokens: 400
      ).strip.presence || fallback_prompt
    rescue Ai::Error
      fallback_prompt
    end

    def prompt_builder_system
      task =
        if @mode == "enhance"
          "an edit instruction for an image model that will transform the user's uploaded photo into a polished social media flyer"
        else
          "a prompt for an image model that will generate a social media graphic from scratch"
        end
      <<~PROMPT
        You write image-generation prompts for the brand "#{@company.name}".
        Turn the user's input into #{task}.
        Describe subject, composition, style, lighting and colors in visual language.
        If short text should appear on the image (an offer, a date, a tagline),
        quote the exact words to render and say where to place them; keep any
        rendered text short. Never include hashtags, emoji, @-handles or
        "link in bio" phrasing. Respond with ONLY the prompt text, no preamble.
      PROMPT
    end

    def prompt_builder_user
      parts = []
      parts << "What the user wants: #{@description}" if @description.present?
      parts << "The post's caption (for context): #{@caption}" if @caption.present?
      parts << "Internal post title: #{@title}" if @title.present?
      parts << "The uploaded photo shows the subject; describe how to restyle it into a flyer." if @mode == "enhance"
      parts.join("\n\n")
    end

    def fallback_prompt
      base = @description.presence || @caption
      if @mode == "enhance"
        "Transform this photo into a clean, modern social media flyer for #{@company.name}. #{base}"
      else
        "A clean, modern social media graphic for #{@company.name}. #{base}. Professional lighting, strong composition, no watermarks."
      end
    end
  end
end
