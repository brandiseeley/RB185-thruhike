require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "securerandom"

require_relative "model_manager"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  also_reload "database_persistence.rb", "model_manager.rb", "thruhike.rb"
end

def logged_in_user
  user_id = session[:user_id]
  # TODO : Handle bad status
  @manager.one_user(user_id).data
end

def logged_in?
  session[:user_id]
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
  redirect "/" unless logged_in?
  @user = logged_in_user
  # TODO : Handle bad status
  @hikes = @manager.all_hikes_from_user(@user.id).data
  erb :hikes
end

get "/hikes/:hike_id" do
  redirect "/" unless logged_in?
  hike_id = params["hike_id"].to_i
  @user = logged_in_user
  # TODO : Handle bad status
  @hike = @manager.one_hike(hike_id).data
  @points = @manager.all_points_from_hike(hike_id).data
  @stats = @manager.hike_stats(@hike)
  erb :hike
end
