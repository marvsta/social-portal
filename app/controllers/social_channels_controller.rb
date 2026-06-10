class SocialChannelsController < ApplicationController
  include CompanyScoped

  def index
    @channels = @company.social_channels.order(:platform, :handle)
  end

  def new
    @channel = @company.social_channels.build(platform: params[:platform] || "instagram", status: "active")
  end

  def create
    @channel = @company.social_channels.build(channel_params)
    if @channel.save
      redirect_to company_social_channels_path(@company), notice: "Channel connected."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @channel = @company.social_channels.find(params[:id])
  end

  def update
    @channel = @company.social_channels.find(params[:id])
    if @channel.update(channel_params)
      redirect_to company_social_channels_path(@company), notice: "Channel updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    channel = @company.social_channels.find(params[:id])
    channel.destroy
    redirect_to company_social_channels_path(@company), notice: "Channel removed."
  end

  private

  def channel_params
    params.require(:social_channel).permit(
      :platform, :handle, :display_name, :avatar_url, :external_account_id,
      :access_token, :token_expires_at, :status
    )
  end
end
