module Admin
  class UsersController < ApplicationController
    before_action :admin_only
    respond_to :html, :json

    def alt_list
      offset = params[:page].to_i || 1
      offset -= 1
      offset = offset.clamp(0, 9999)
      offset *= 250
      @alts = User.connection.select_all <<~SQL.squish
        SELECT u1.id as u1id, u2.id as u2id
        FROM (SELECT * FROM users ORDER BY id DESC LIMIT 250 OFFSET #{offset}) u1
        INNER JOIN users u2 ON u1.last_ip_addr = u2.last_ip_addr AND u1.id != u2.id AND u2.last_logged_in_at > now() - interval '3 months'
        ORDER BY u1.id DESC, u2.last_logged_in_at DESC;
      SQL
      @alts = @alts.group_by { |i| i["u1id"] }.transform_values { |v| v.pluck("u2id") }
      user_ids = @alts.flatten(2).uniq
      @users = User.where(id: user_ids).index_by(&:id)
      @alts = YiffyAPI::Paginator::PaginatedArray.new(@alts.to_a, { mode: :numbered, per_page: 250, total: 9_999_999_999, current_page: params[:page].to_i })
      respond_with(@alts)
    end

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      @user.validate_email_format = true
      @user.skip_email_blank_check = true
      @user.update!(user_params)
      if @user.saved_change_to_profile_about || @user.saved_change_to_profile_artinfo
        ModAction.log(:user_text_change, { user_id: @user.id })
      end
      if @user.saved_change_to_base_upload_limit
        ModAction.log(:user_upload_limit_change, { user_id: @user.id, old_upload_limit: @user.base_upload_limit_before_last_save, new_upload_limit: @user.base_upload_limit })
      end
      @user.mark_verified! if params[:user][:verified] == 'true'
      @user.mark_unverified! if params[:user][:verified] == 'false'
      @user.promote_to!(params[:user][:level], params[:user])

      old_username = @user.name
      desired_username = params[:user][:name]
      if old_username != desired_username && desired_username.present?
        change_request = UserNameChangeRequest.create!({
                                                           original_name: @user.name,
                                                           user_id: @user.id,
                                                           desired_name: desired_username,
                                                           change_reason: "Administrative change",
                                                           skip_limited_validation: true})
        change_request.approve!
      end
      redirect_to user_path(@user), notice: "User updated"
    end

    def edit_blacklist
      @user = User.find(params[:id])
    end

    def update_blacklist
      @user = User.find(params[:id])
      @user.update!(params[:user].permit([:blacklisted_tags]))
      ModAction.log(:user_blacklist_changed, {user_id: @user.id})
      redirect_to edit_blacklist_admin_user_path(@user), notice: "Blacklist updated"
    end

    def request_password_reset
      @user = User.find(params[:id])
    end

    def password_reset
      @user = User.find(params[:id])

      unless User.authenticate(CurrentUser.name, params[:admin][:password])
        return redirect_to request_password_reset_admin_user_path(@user), notice: "Password wrong"
      end

      @reset_key = UserPasswordResetNonce.create(user_id: @user.id)
    end

    private

    def user_params
      params.require(:user).slice(:profile_about, :profile_artinfo, :email, :base_upload_limit, :enable_privacy_mode).permit([:profile_about, :profile_artinfo, :email, :base_upload_limit, :enable_privacy_mode])
    end
  end
end
