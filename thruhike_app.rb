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

def logged_in_user
  user_id = session[:user_id]
  # TODO : Handle bad status
  @manager.one_user(user_id).data
end

def logged_in?
  session[:user_id]
end

def valid_hike?(name, start_mileage, finish_mileage, user)
  # Validation goes here
  true
end

def valid_point?(hike, mileage, date)
  # Validation goes here
  true
end

def require_login
  session[:message] = "You must be logged in to do that"
  redirect "/"
end

before do
  @manager = ModelManager.new
end

get "/" do
  # TODO : Handle bad status
  @users = @manager.all_users.data
  erb :home
end

post "/hikes" do
  user_id = params["user_id"]
  session[:user_id] = user_id
  # TODO: validate user exists
  redirect "/hikes"
end

get "/hikes" do
  require_login unless logged_in?
  @user = logged_in_user
  # TODO : Handle bad status
  @hikes = @manager.all_hikes_from_user(@user.id).data
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
  start_mileage = params[:start_mileage].to_f
  finish_mileage = params[:finish_mileage].to_f
  user = logged_in_user

  if !valid_hike?(hike_name, start_mileage, finish_mileage, user)
    session[:message] = "Some input was wrong"
  else
    hike = Hike.new(user, start_mileage, finish_mileage, hike_name, false)
    status = @manager.insert_new_hike(hike)
    if status.success
      session[:message] = "Hike successfully created"
      redirect "/hikes"
    else
      session[:message] = "There was an error creating this hike"
    end
  end
  puts session[:message]
  redirect "/hikes/new"
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

  if valid_point?(hike, mileage, date)
    point = Point.new(hike, mileage, date)
    status = @manager.insert_new_point(point)
    if status.success
      session[:message] = "Point successfully created"
      redirect "/hikes/#{hike_id}"
    end
  end
  session[:message] = "There was an error, point creation unsuccessful"
  redirect "/hikes/#{hike_id}"
end
