class AiSettingsController < ApplicationController
  # AI settings are global (all companies), so the gate is "manages at least
  # one company" rather than a per-company role check.
  before_action :require_any_manager, only: %i[update test]

  def show
    @setting = AppSetting.current
    @can_edit = any_manager?
  end

  def update
    @setting = AppSetting.current
    if @setting.update(setting_params)
      redirect_to ai_settings_path,
        notice: "AI settings saved — using #{Ai::Providers.label(@setting.ai_provider)} · #{@setting.ai_model_or_default}."
    else
      @can_edit = true
      render :show, status: :unprocessable_content
    end
  end

  # Fires a tiny real request at the selected provider so a bad key or model
  # shows up here instead of mid-caption-writing.
  def test
    setting = AppSetting.current
    reply = Ai::Providers.client_for(setting.ai_provider).chat(
      model: setting.ai_model_or_default,
      system: "You are a connection test. Reply with exactly: ok",
      user: "Connection test.",
      max_tokens: 20
    )
    render json: { ok: true, provider: Ai::Providers.label(setting.ai_provider), model: setting.ai_model_or_default, reply: reply.strip }
  rescue Ai::Error => e
    render json: { ok: false, error: e.message }, status: :unprocessable_content
  end

  private

  def any_manager?
    current_user.memberships.exists?(role: %w[owner admin])
  end

  def require_any_manager
    deny_access unless any_manager?
  end

  def setting_params
    params.require(:app_setting).permit(:ai_provider, :ai_model)
  end
end
