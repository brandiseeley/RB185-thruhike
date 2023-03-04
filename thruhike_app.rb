require "pry"
require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "securerandom"

require_relative "model_manager"
require_relative "models"
require_relative "validate"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  also_reload "database_persistence.rb", "model_manager.rb", "thruhike.rb", "validate.rb" if development?
end

before do
  @manager = ModelManager.new
end

# View Helpers
helpers do
  def miles_since_last_point(points, point, hike)
    points = points.reverse
    return (point.mileage - hike.start_mileage).round(2) if points.find_index(point).zero?

    previous_point = points[points.find_index(point) - 1]
    (point.mileage - previous_point.mileage).round(2)
  end

  def percent_complete(points, hike)
    return 0 if points.empty?

    (points.first.mileage / hike.finish_mileage * 100).round(2)
  end
end

# Route Helpers
helpers Validate

helpers do
  def logged_in?
    session[:user_id]
  end

  def logged_in_user
    user_id = session[:user_id]

    # TODO : This validation needs tested
    status = @manager.one_user(user_id)
    unless status.success
      session[:message] = "User not found"
      redirect "/"
    end

    status.data
  end

  def logged_in?
    session[:user_id]
  end

  def require_login
    session[:message] = "You must be logged in to do that"
    redirect "/"
  end
end

# Routes

get "/" do
  # TODO : Handle bad status
  @users = @manager.all_users.data
  erb :home
end

get "/logout" do
  session[:user_id] = nil
  redirect "/"
end

get "/hikes" do
  require_login unless logged_in?
  @user = logged_in_user
  # TODO : Handle bad status
  @hikes = @manager.all_hikes_from_user(@user.id).data
  erb :hikes
end

post "/hikes" do
  user_id = params["user_id"]
  session[:user_id] = user_id
  # TODO: validate user exists
  redirect "/hikes"
end

get "/hikes/new" do
  require_login unless logged_in?
  @user = logged_in_user

  erb :new_hike
end

post "/hikes/new" do
  require_login unless logged_in?
  hike_name = params[:name]
  start_mileage = params[:start_mileage]
  finish_mileage = params[:finish_mileage]
  user = logged_in_user

  validate_hike_data_types(hike_name, start_mileage, finish_mileage)
  start_mileage = start_mileage.to_f
  finish_mileage = finish_mileage.to_f

  validate_hike_details(hike_name, start_mileage, finish_mileage, user)
  hike = Hike.new(user, start_mileage, finish_mileage, hike_name, false)
  status = @manager.insert_new_hike(hike)
  if status.success
    session[:message] = "Hike successfully created"
    redirect "/hikes/#{status.data}"
  else
    session[:message] = "There was an error creating this hike"
  end
  redirect "/hikes/new"
end

post "/hikes/delete" do
  require_login unless logged_in?
  hike_id = params[:hike_id].to_i
  validate_hike_to_edit(hike_id, session[:user_id])
  status = @manager.delete_hike(hike_id)

  session[:message] = status.success ? "Hike successfully deleted" : "There was an error deleting hike"
  redirect "/hikes"
end

get "/hikes/:hike_id" do
  require_login unless logged_in?
  hike_id = params["hike_id"].to_i
  @user = logged_in_user
  # TODO : Handle bad status
  @hike = @manager.one_hike(hike_id).data
  @points = @manager.all_points_from_hike(hike_id).data
  @stats = @manager.hike_stats(@hike)
  erb :hike
end

post "/hikes/:hike_id" do
  require_login unless logged_in?
  user = logged_in_user
  hike_id = params["hike_id"]
  date = params[:date]
  mileage = params[:mileage]
  hike_attempt = @manager.one_hike(hike_id)

  validate_point_data_types(hike_attempt, mileage, date, hike_id)
  hike = hike_attempt.data
  mileage = mileage.to_f

  validate_point_details(hike, mileage, date, hike_id, user)

  point = Point.new(hike, mileage, date)
  status = @manager.insert_new_point(point)

  session[:message] = status.success ? "Point successfully created" : "There was an error creating point"
  redirect "/hikes/#{hike_id}"
end

post "/hikes/:hike_id/delete" do
  require_login unless logged_in?
  hike_id = params[:hike_id]
  point_id = params[:point_id]
  user = logged_in_user
  unless validate_user_owns_hike_and_point?(user.id, point_id, hike_id)
    session[:message] = "Permission to edit this hike denied"
    redirect "/hikes"
  end

  attempt = @manager.delete_point(point_id)
  session[:message] = attempt.success ? "Point successfully deleted" : "There was an error deleting point"
  redirect "/hikes/#{hike_id}"
end

get "/hikes/:hike_id/edit" do
  require_login unless logged_in?
  user = logged_in_user
  hike_id = params["hike_id"].to_i
  validate_hike_to_edit(hike_id, user.id)
  @hike = @manager.one_hike(hike_id).data
  erb :edit_hike
end

post "/hikes/:hike_id/edit" do
  require_login unless logged_in?
  user = logged_in_user
  hike_id = params[:hike_id].to_i
  validate_hike_to_edit(hike_id, user.id)
  @hike = @manager.one_hike(hike_id).data

  new_hike_name = params["name"]
  new_start_mileage = params["start_mileage"]
  new_finish_mileage = params["finish_mileage"]
  validate_hike_data_types(new_hike_name, new_start_mileage, new_finish_mileage)

  validate_edit_hike_details(user, hike_id, new_hike_name, new_start_mileage, new_finish_mileage)

  @manager.update_hike_name(hike_id, new_hike_name)
  @manager.update_hike_start_mileage(hike_id, new_start_mileage)
  @manager.update_hike_finish_mileage(hike_id, new_finish_mileage)

  redirect "/hikes/#{hike_id}"
end
