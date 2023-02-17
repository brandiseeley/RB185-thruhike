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

get "/hikes" do
  user_name = params["user"]
  session[:user] = user_name
  @user = @manager.one_user(user_name)
  erb :hikes
end
