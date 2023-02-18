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
  user_id = session[:user_id]
  @user = @manager.one_user(user_id)
  # TODO : Partition hikes into active hikes and completed hikes
  @hikes = @manager.all_hikes_from_user(user_id)
  erb :hikes
end
