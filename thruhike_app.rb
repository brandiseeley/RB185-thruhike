require "pry"
require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "securerandom"
require "yaml"
require "bcrypt"

require_relative "model_manager"
require_relative "models"
require_relative "validate"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
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

  def required_pace(goal, hike, last_point)
    distance_to_go = goal.mileage - last_point.mileage
    days_to_go = goal.date - last_point.date
    (distance_to_go / days_to_go).round(3)
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

  def valid_credentials?(user_name, password)
    credentials = load_user_credentials

    return false unless credentials.key?(user_name)
    bcrypt_password = BCrypt::Password.new(credentials[user_name])
    bcrypt_password == password
  end

  def load_user_credentials
    credentials_path = if ENV["RACK_ENV"] == "test"
      File.expand_path("../test/users.yml", __FILE__)
    else
      File.expand_path("../users.yml", __FILE__)
    end
    YAML.load_file(credentials_path)
  end

  def id_from_user_name(user_name)
    id_attempt = @manager.id_from_user_name(user_name)
    return nil unless id_attempt.success
    id_attempt.data
  end

  def user_name_available?(user_name)
    id_from_user_name(user_name).nil?
  end

  def fetch_hike_if_exists(hike_id)
    hike_attempt = @manager.one_hike(hike_id)
    return hike_attempt.data if hike_attempt.success
    session[:message] = hike_attempt.message
    redirect back
  end

  def check_hike_ownership(user, hike)
    return if hike.user == user
    session[:message] = "Permission denied, unable to fetch hike"
    redirect back
  end

  def fetch_point_if_exists(hike, point_id)
    point_attempt = @manager.one_point(hike, point_id)
    return point_attempt.data if point_attempt.success
    session[:message] = point_attempt.message
    redirect back
  end

  def check_point_ownership(hike, point)
    return if point.hike == hike
    session[:message] = "Permission denied, unable to fetch point"
    redirect back
  end

  def fetch_goal_if_exists(hike, goal_id)
    goal_attempt = @manager.one_goal(hike, goal_id)
    return goal_attempt.data if goal_attempt.success
    session[:message] = goal_attempt.message
    redirect back
  end

  def check_goal_ownership(hike, goal)
    return if hike == goal.hike
    session[:message] = "Permission denied, unable to fetch goal"
    redirect back
  end
end

# Routes

get "/" do
  erb :home
end

get "/sign_in" do
  erb :sign_in
end

post "/sign_in" do
  credentials = load_user_credentials
  user_name = params[:user_name]

  if valid_credentials?(user_name, params[:password])
    id = id_from_user_name(user_name)
    if id.nil?
      session[:message] = "There was an error logging in"
      redirect "/hikes"
    end

    session[:user_id] = id
    session[:message] = "Welcome!"
    redirect "/hikes"
  else
    session[:message] = "Invalid credentials"
    erb :sign_in
  end
end

get "/sign_up" do
  erb :sign_up
end

post "/sign_up" do
  if params[:password] != params[:confirm_password]
    session[:message] = "Passwords don't match"
    erb :sign_up
  elsif !user_name_available?(params[:user_name])
    session[:message] = "Username already taken"
    erb :sign_up
  else
    # TODO : Restrict format for fields
    # TODO : Create new user
  end
end

get "/log_out" do
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
  hike = fetch_hike_if_exists(hike_id)
  check_hike_ownership(user, hike)

  status = @manager.delete_hike(hike, user)

  session[:message] = status.success ? "Hike successfully deleted" : status.message
  redirect "/hikes"
end

get "/hikes/:hike_id" do
  require_login unless logged_in?
  @user = logged_in_user
  hike_id = params["hike_id"].to_i

  @hike = fetch_hike_if_exists(hike_id)
  check_hike_ownership(@user, @hike)

  # TODO : Validate user owns hike
  
  points_attempt = @manager.all_points_from_hike(@hike)
  unless points_attempt.success
    session[:message] = points_attempt.message
    redirect "/hikes"
  end

  goals_attempt = @manager.all_goals_from_hike(@hike)
  unless goals_attempt.success
    session[:message] = goals_attempt.message
    redirect "/hikes"
  end

  @points = points_attempt.data
  @goals = goals_attempt.data

  # TODO : Hike Stats isn't functioning properly. Lacks validation
  @stats = @manager.hike_stats(@hike)

  erb :hike
end

post "/hikes/:hike_id/points/new" do
  require_login unless logged_in?

  user = logged_in_user
  hike_id = params["hike_id"]
  hike = fetch_hike_if_exists(hike_id)
  check_hike_ownership(user, hike)

  date = params[:date]
  mileage = params[:mileage]

  validate_point_data_types(mileage, date, hike_id)
  mileage = mileage.to_f
  date = Date.parse(date)

  point = Point.new(hike, mileage, date)
  status = @manager.insert_new_point(point)

  session[:message] = status.success ? "Point successfully created" : status.message
  redirect "/hikes/#{hike_id}"
end

post "/hikes/:hike_id/points/delete" do
  require_login unless logged_in?
  hike_id = params[:hike_id]
  user = logged_in_user
  hike = fetch_hike_if_exists(hike_id)
  check_hike_ownership(user, hike)

  point = fetch_point_if_exists(hike, params[:point_id])
  check_point_ownership(hike, point)

  attempt = @manager.delete_point(point)
  session[:message] = attempt.success ? "Point successfully deleted" : attempt.message
  redirect "/hikes/#{hike_id}"
end

post "/hikes/:hike_id/goals/new" do
  require_login unless logged_in?
  user = logged_in_user
  hike_id = params[:hike_id]
  hike = fetch_hike_if_exists(hike_id)
  check_hike_ownership(user, hike)

  date = params[:date]
  description = params[:description]
  mileage = params[:mileage]

  validate_goal_data_types(hike_id, date, description, mileage)

  date = Date.parse(date)
  description = description.strip
  mileage = mileage.to_f

  goal = Goal.new(date, mileage, description, hike)
  attempt = @manager.insert_new_goal(user, goal)

  session[:message] = attempt.success ? "Goal successfully created" : attempt.message
  redirect "/hikes/#{hike_id}"
end

post "/hikes/:hike_id/goals/delete" do
  require_login unless logged_in?
  user = logged_in_user
  hike_id = params[:hike_id]
  goal_id = params[:goal_id]
  hike = fetch_hike_if_exists(hike_id)
  check_hike_ownership(user, hike)

  goal = fetch_goal_if_exists(hike, goal_id)
  check_goal_ownership(hike, goal)

  goal_id = params[:goal_id].to_i

  attempt = @manager.delete_goal(user, hike, goal_id)
  session[:message] = attempt.success ? "Goal successfully deleted" : attempt.message
  redirect "/hikes/#{hike_id}"
end

get "/hikes/:hike_id/edit" do
  require_login unless logged_in?
  user = logged_in_user
  hike_id = params["hike_id"]
  @hike = fetch_hike_if_exists(hike_id)
  check_hike_ownership(user, @hike)
  # TODO : Validate user owns hike

  erb :edit_hike
end

post "/hikes/:hike_id/edit" do
  require_login unless logged_in?
  user = logged_in_user
  hike_id = params[:hike_id].to_i
  hike = fetch_hike_if_exists(hike_id)
  check_hike_ownership(user, hike)


  new_hike_name = params["name"]
  new_start_mileage = params["start_mileage"]
  new_finish_mileage = params["finish_mileage"]
  validate_hike_data_types(new_hike_name, new_start_mileage, new_finish_mileage)

  status = @manager.update_hike_details(user, hike, new_hike_name, new_start_mileage, new_finish_mileage)

  session[:message] = status.success ? "Hike successfully edited" : status.message
  redirect "/hikes/#{hike_id}/edit" unless status.success
  redirect "/hikes/#{hike_id}"
end
