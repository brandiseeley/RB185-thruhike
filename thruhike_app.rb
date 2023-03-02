require "pry"
require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "securerandom"

require_relative "model_manager"
require_relative "models"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  also_reload "database_persistence.rb", "model_manager.rb", "thruhike.rb" if development?
end

before do
  @manager = ModelManager.new
end

### USER HELPERS ###

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

### VALIDATION HELPERS ###

# TODO : validate mileage?
def validate_point_details(hike, mileage, date, hike_id, user)
  points = @manager.all_points_from_hike(hike_id).data
  error = false
  if points.any? { |p| to_date(date) === p.date }
    session[:message] = "Each day may only have one point"
    error = true
  elsif !(hike.start_mileage..hike.finish_mileage).cover?(mileage)
    session[:message] = "Mileage must be between #{hike.start_mileage} and #{hike.finish_mileage}"
    error = true
  elsif !user_owns_hike?(user.id, hike_id)
    session[:message] = "Permission to edit this hike denied"
    error = true
  end
  redirect "/hikes/#{hike_id}" if error
end

def validate_point_data_types(hike_attempt, mileage, date, hike_id)
  error = false
  if !is_numeric?(hike_id) || !hike_attempt.success
    session[:message] = "Error retreiving hike"
    error = true
  elsif !is_numeric?(mileage)
    session[:message] = "Invalid Mileage"
    error = true
  elsif date !~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/
    session[:message] = "Invalid Date"
    error = true 
  end
  redirect "/hikes/#{hike_id}" if error
end

def validate_hike_data_types(hike_name, start_mileage, finish_mileage)
  error = false
  unless hike_name && start_mileage && finish_mileage
    session[:message] = "All fields are required"
    redirect "/hikes/new"
  end
  if hike_name.strip.empty?
    session[:message] = "Hike name must be non-empty"
    error = true
  elsif !is_numeric?(start_mileage)
    session[:message] = "Invalid Start Mileage"
    error = true
  elsif !is_numeric?(finish_mileage)
    session[:message] = "Invalid Finish Mileage"
    error = true
  end
  redirect "/hikes/new" if error
end

def validate_hike_details(hike_name, start_mileage, finish_mileage, user)
  error = false
  if start_mileage < 0 || finish_mileage < 0
    session[:message] = "Mileages must be non-negative"
    error = true
  elsif finish_mileage - start_mileage <= 0
    session[:message] = "Finishing mileage must be greater than starting mileage"
    error = true
  elsif duplicate_name?(hike_name, user)
    session[:message] = "You already have a hike titled '#{hike_name}'"
    error = true
  end
  redirect "/hikes/new" if error
end

# Ensures hike belongs to currently logged in user
def validate_hike_to_delete(hike_id, user_id)
  unless user_owns_hike?(user_id, hike_id)
    session[:message] = "Permission denied, unable to delete hike"
    redirect "/hikes"
  end
end

def duplicate_name?(hike_name, user)
  all_hikes = @manager.all_hikes_from_user(user.id).data
  all_hikes.any? { |hike| hike.name == hike_name }
end

def is_numeric?(string)
  string.to_i.to_s == string || string.to_f.to_s == string
end

def to_date(string)
  Date.parse(string)
end

def user_owns_hike?(user_id, hike_id)
  # binding.pry
  all_hikes_status = @manager.all_hikes_from_user(user_id)
  if all_hikes_status.success
    all_hikes_status.data.any? { |hike| hike.id == hike_id.to_i }
  else
    false
  end
end

### FETCHING HELPERS ###

### ROUTES ###

get "/" do
  # TODO : Handle bad status
  @users = @manager.all_users.data
  erb :home
end

get "/hikes" do
  require_login unless logged_in?
  @user = logged_in_user
  @hikes = @manager.all_hikes_from_user(@user.id).data
  erb :hikes
end

post "/hikes" do
  user_id = params["user_id"]
  # TODO : Validate user exists
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
    redirect "/hikes"
  else
    session[:message] = "There was an error creating this hike"
  end
  redirect "/hikes/new"
end

post "/hikes/delete" do
  require_login unless logged_in?
  hike_id = params[:hike_id].to_i
  validate_hike_to_delete(hike_id, session[:user_id])
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
  point_id = params[:point_id]
  hike_id = params[:hike_id]

  attempt = @manager.delete_point(point_id)
  session[:message] = attempt.success ? "Point successfully deleted" : "There was an error deleting point"
  redirect "/hikes/#{hike_id}"
end
