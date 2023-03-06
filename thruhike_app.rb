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

    ((points.first.mileage - hike.start_mileage) / (hike.finish_mileage - hike.start_mileage) * 100).round(2)
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
  all_users_attempt = @manager.all_users
  @users = all_users_attempt.success ? all_users_attempt.data : []
  erb :home
end

get "/logout" do
  session[:user_id] = nil
  redirect "/"
end

get "/hikes" do
  require_login unless logged_in?
  @user = logged_in_user

  hikes_attempt = @manager.all_hikes_from_user(@user.id)
  unless hikes_attempt.success
    session[:message] = "There was an error loading your hikes"
    redirect "/"
  end
  @hikes = hikes_attempt.data
  erb :hikes
end

post "/hikes" do
  user_id = params["user_id"]
  user_attempt = @manager.one_user(user_id)
  if user_attempt.success
    session[:user_id] = user_id
    redirect "/hikes"
  else
    session[:message] = "There was an error logging in, try again"
    redirect "/"
  end
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

  hike = Hike.new(user, start_mileage, finish_mileage, hike_name, false)
  status = @manager.insert_new_hike(hike)
  if status.success
    session[:message] = "Hike successfully created"
    redirect "/hikes/#{status.data}"
  else
    session[:message] = status.message
  end
  redirect "/hikes/new"
end

post "/hikes/delete" do
  require_login unless logged_in?
  hike_id = params[:hike_id].to_i
  user = logged_in_user
  status = @manager.delete_hike(hike_id, user)

  session[:message] = status.success ? "Hike successfully deleted" : status.message
  redirect "/hikes"
end

get "/hikes/:hike_id" do
  require_login unless logged_in?
  hike_id = params["hike_id"].to_i
  @user = logged_in_user

  hike_attempt = @manager.one_hike(hike_id)
  points_attempt = @manager.all_points_from_hike(hike_id)

  unless hike_attempt.success
    session[:message] = hike_attempt.message
    redirect "/hikes"
  end

  unless points_attempt.success
    session[:message] = points_attempt.message
    redirect "/hikes"
  end

  @hike = hike_attempt.data
  @points = points_attempt.data

  # TODO : Hike Stats isn't functioning properly. Lacks validation
  @stats = @manager.hike_stats(@hike)

  erb :hike
end

post "/hikes/:hike_id" do
  require_login unless logged_in?
  hike_id = params["hike_id"]
  date = params[:date]
  mileage = params[:mileage]
  hike_attempt = @manager.one_hike(hike_id)

  validate_point_data_types(hike_attempt, mileage, date, hike_id)
  hike = hike_attempt.data
  mileage = mileage.to_f
  date = Date.parse(date)

  point = Point.new(hike, mileage, date)
  status = @manager.insert_new_point(point)

  session[:message] = status.success ? "Point successfully created" : status.message
  redirect "/hikes/#{hike_id}"
end

post "/hikes/:hike_id/delete" do
  require_login unless logged_in?
  hike_id = params[:hike_id]
  point_id = params[:point_id]
  user = logged_in_user

  attempt = @manager.delete_point(user, point_id)
  session[:message] = attempt.success ? "Point successfully deleted" : attempt.message
  redirect "/hikes/#{hike_id}"
end

get "/hikes/:hike_id/edit" do
  require_login unless logged_in?
  hike_id = params["hike_id"].to_i

  hike_attempt = @manager.one_hike(hike_id)
  unless hike_attempt.success
    session[:message] = hike_attempt.message
    redirect "/hikes/#{hike_id}"
  end

  @hike = hike_attempt.data
  erb :edit_hike
end

post "/hikes/:hike_id/edit" do
  require_login unless logged_in?
  user = logged_in_user
  hike_id = params[:hike_id].to_i

  hike_attempt = @manager.one_hike(hike_id)
  unless hike_attempt.success
    session[:message] = hike_attempt.message
    redirect "/hikes/#{hike_id}"
  end

  @hike = hike_attempt.data

  new_hike_name = params["name"]
  new_start_mileage = params["start_mileage"]
  new_finish_mileage = params["finish_mileage"]
  validate_hike_data_types(new_hike_name, new_start_mileage, new_finish_mileage)

  status = @manager.update_hike_details(user, hike_id, new_hike_name, new_start_mileage, new_finish_mileage)

  session[:message] = status.success ? "Hike successfully edited" : status.message
  redirect "/hikes/#{hike_id}/edit" unless status.success
  redirect "/hikes/#{hike_id}"
end
