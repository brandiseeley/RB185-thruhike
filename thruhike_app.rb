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
  if !status.success
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

def validate_point_details(hike, mileage, date, hike_id)
end

def validate_hike_details(hike_name, start_mileage, finish_mileage, user)
  if hike_name.empty?
    session[:message] = "Hike name must be non-empty"
    redirect "/hikes/new"
  elsif finish_mileage - start_mileage <= 0
    session[:message] = "Finishing mileage must be greater than starting mileage"
    redirect "/hikes/new"
  elsif duplicate_name?(hike_name, user)
    session[:message] = "You already have a hike titled '#{hike_name}'"
    redirect "/hikes/new"
  end
end

# Ensures hike belongs to currently logged in user
def validate_hike_to_delete(hike_id, user_id)
  all_hikes_status = @manager.all_hikes_from_user(user_id)
  if all_hikes_status.success
    if all_hikes_status.data.none? { |hike| hike.id == hike_id }
      session[:message] = "Permission denied, unable to delete hike"
      redirect "/hikes"
    end
  else
    session[:message] = "There was an error retrieving your hikes"
  end
end

def duplicate_name?(hike_name, user)
  all_hikes = @manager.all_hikes_from_user(user.id).data
  all_hikes.any? { |hike| hike.name == hike_name }
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
  hike_name = params[:name].strip
  start_mileage = params[:start_mileage].to_f
  finish_mileage = params[:finish_mileage].to_f
  user = logged_in_user

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
  hike_id = params["hike_id"].to_i
  date = params[:date]
  mileage = params[:mileage]
  hike = @manager.one_hike(hike_id).data

  validate_point_details(hike, mileage, date, hike_id)
  point = Point.new(hike, mileage, date)
  status = @manager.insert_new_point(point)
  
  session[:message] = status.success ? "Point successfully created" : "There was an error creating point"
  redirect "/hikes/#{hike_id}"
end

post "/hikes/:hike_id/delete" do
  point_id = params[:point_id]

  attempt = @manager.delete_point(point_id)
  session[:message] = attempt.success ? "Point successfully deleted" : "There was an error deleting point"
  redirect "/hikes/#{hike_id}"
end
