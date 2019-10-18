class Devise::MasqueradesController < DeviseController
  prepend_before_action :authenticate_scope!, :masquerade_authorize!

  before_action :save_masquerade_owner_session, :only => :show

  after_action :cleanup_masquerade_owner_session, :only => :back

  def show
    self.resource = find_resource

    unless resource
      flash[:error] = "#{masqueraded_resource_class} not found."
      redirect_to(new_user_session_path) and return
    end

    resource.masquerade!
    request.env["devise.skip_trackable"] = "1"

    masquerade_sign_in(resource)

    go_back(resource)
  end

  def back
    user_id = session[session_key]

    owner_user = if user_id.present?
                   masquerading_resource_class.to_adapter.find_first(:id => user_id)
                 else
                   send(:"current_#{masquerading_resource_name}")
                 end

    if masquerading_resource_class != masqueraded_resource_class
      sign_out(send("current_#{masqueraded_resource_name}"))
    end

    masquerade_sign_in(owner_user)
    request.env["devise.skip_trackable"] = nil

    go_back(owner_user)
  end

  protected

  def masquerade_authorize!
    head(403) unless masquerade_authorized?
  end

  def masquerade_authorized?
    true
  end

  def find_resource
    masqueraded_resource_class.to_adapter.find_first(:id => params[:id])
  end

  def go_back(owner_user)
    if Devise.masquerade_routes_back
      redirect_back(
        fallback_location: after_back_masquerade_path_for(owner_user))
    else
      redirect_to after_back_masquerade_path_for(owner_user)
    end
  end

  private

  def masqueraded_resource_class
    Devise.masqueraded_resource_class || resource_class
  end

  def masqueraded_resource_name
    Devise.masqueraded_resource_name || masqueraded_resource_class.model_name.param_key
  end

  def masquerading_resource_class
    Devise.masquerading_resource_class || resource_class
  end

  def masquerading_resource_name
    Devise.masquerading_resource_name || masquerading_resource_class.model_name.param_key
  end

  def authenticate_scope!
    send(:"authenticate_#{masquerading_resource_name}!", :force => true)
  end

  def after_masquerade_path_for(resource)
    "/"
  end

  def after_masquerade_full_path_for(resource)
    if after_masquerade_path_for(resource) =~ /\?/
      "#{after_masquerade_path_for(resource)}&#{after_masquerade_param_for(resource)}"
    else
      "#{after_masquerade_path_for(resource)}?#{after_masquerade_param_for(resource)}"
    end
  end

  def after_masquerade_param_for(resource)
    "#{Devise.masquerade_param}=#{resource.masquerade_key}"
  end

  def after_back_masquerade_path_for(resource)
    '/'
  end

  def save_masquerade_owner_session
    unless session.key?(session_key)
      session[session_key] = send("current_#{masquerading_resource_name}").id
    end
  end

  def cleanup_masquerade_owner_session
    session.delete(session_key)
  end

  def session_key
    "devise_masquerade_#{masqueraded_resource_name}".to_sym
  end
end
