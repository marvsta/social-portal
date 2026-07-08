module Ai
  # Registry of supported AI providers and their models. The active provider
  # and model are chosen globally on the AI settings screen (AppSetting.current);
  # API keys stay in ENV and are never stored in the database.
  module Providers
    REGISTRY = {
      "anthropic" => {
        label: "Anthropic (Claude)",
        env_key: "ANTHROPIC_API_KEY",
        default_model: "claude-sonnet-5",
        models: [
          ["Claude Sonnet 5 — best balance (recommended)", "claude-sonnet-5"],
          ["Claude Opus 4.8 — most capable", "claude-opus-4-8"],
          ["Claude Haiku 4.5 — fastest & cheapest", "claude-haiku-4-5-20251001"]
        ]
      },
      "openai" => {
        label: "OpenAI (GPT)",
        env_key: "OPENAI_API_KEY",
        default_model: "gpt-5.1",
        models: [
          ["GPT-5.1 — flagship", "gpt-5.1"],
          ["GPT-5 mini — fast & cheap", "gpt-5-mini"],
          ["GPT-5 nano — lightest & cheapest", "gpt-5-nano"],
          ["GPT-4.1 mini — light, strong quality", "gpt-4.1-mini"],
          ["GPT-4.1 nano — ultra cheap", "gpt-4.1-nano"],
          ["GPT-4o", "gpt-4o"],
          ["GPT-4o mini — cheap legacy", "gpt-4o-mini"]
        ]
      }
    }.freeze

    CLIENTS = {
      "anthropic" => "Ai::Providers::Anthropic",
      "openai"    => "Ai::Providers::Openai"
    }.freeze

    # Image generation is OpenAI-only (Anthropic doesn't generate images), so
    # it isn't part of the provider toggle — just a model + quality choice.
    IMAGE_MODELS = [
      ["GPT Image 1 mini — cheapest, great for drafts", "gpt-image-1-mini"],
      ["GPT Image 1 — best quality & text rendering", "gpt-image-1"]
    ].freeze

    IMAGE_QUALITIES = [
      ["Low — ~1 cent per image", "low"],
      ["Medium — a few cents, good default", "medium"],
      ["High — up to ~17 cents, crispest", "high"]
    ].freeze

    def self.image_model_ids
      IMAGE_MODELS.map(&:last)
    end

    def self.image_quality_ids
      IMAGE_QUALITIES.map(&:last)
    end

    def self.keys
      REGISTRY.keys
    end

    def self.config(key)
      REGISTRY.fetch(key) { raise Ai::Error, "Unknown AI provider: #{key}" }
    end

    def self.label(key)
      config(key)[:label]
    end

    def self.models(key)
      config(key)[:models]
    end

    def self.model_ids(key)
      models(key).map(&:last)
    end

    def self.default_model(key)
      config(key)[:default_model]
    end

    def self.env_key(key)
      config(key)[:env_key]
    end

    def self.configured?(key)
      ENV[env_key(key)].present?
    end

    def self.client_for(key)
      config(key) # raises on unknown key
      CLIENTS.fetch(key).constantize
    end
  end
end
