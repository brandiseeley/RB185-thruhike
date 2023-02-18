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
  @manager.one_user(user_id)
end

before do
  @manager = ModelManager.new
end

get "/" do
  @users = @manager.all_users
  erb :home
end

post "/hikes" do
  user_id = params["user_id"]
  # TODO: Login Validation
  session[:user_id] = user_id
  redirect "/hikes"
end

get "/hikes" do
  @user = logged_in_user
  @hikes = @manager.all_hikes_from_user(@user.id)
  erb :hikes
end

get "/hikes/:hike_id" do
  puts "Here's the session user id!"
  puts session[:user_id]
  hike_id = params["hike_id"].to_i
  @user = logged_in_user
  @hike = @manager.one_hike(hike_id)
  @points = @manager.all_points_from_hike(hike_id)
  erb :hike
end
