class Users::RegistrationsController < Devise::RegistrationsController
  
  def new
    redirect_to user_bike_index_omniauth_authorize_path and return
  end

end