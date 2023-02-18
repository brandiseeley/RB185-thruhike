require_relative "thruhike"
require_relative "database_persistence"
require "pry-byebug"

# Uses values returned from DatabasePersistence, returns constructed objects
class ModelManager
  def initialize
    @database = DatabasePersistence.new
  end

  # returns array of User objects
  def all_users
    @database.all_users.map do |user_data|
      construct_user(user_data)
    end.sort
  end

  def one_user(user_id)
    user = @database.one_user(user_id).first
    construct_user(user)
  end

  def all_hikes_from_user(user_id)
    hikes = @database.all_hikes_from_user(user_id)
    hikes.map do |hike_data|
      construct_hike(hike_data)
    end.sort
  end

  def one_hike(hike_id)
    hike_data = @database.one_hike(hike_id)
    construct_hike(hike_data)
  end

  def all_points_from_hike(hike_id)
    hike_object = one_hike(hike_id)
    points_data = @database.all_points_from_hike(hike_id)
    points_data.map do |point_data|
      construct_point(point_data, hike_object)
    end
  end

  private

  def construct_user(row)
    User.new(row["name"],
             row["user_name"],
             row["id"].to_i)
  end

  def construct_hike(row)
    user_id = row["user_id"].to_i
    user = one_user(user_id)
    Hike.new(user,
             row["start_mileage"].to_f,
             row["finish_mileage"].to_f,
             row["name"],
             row["completed"] == "t",
             row["id"].to_i)
  end

  def construct_point(row, hike)
    Point.new(hike,
              row["mileage"].to_f,
              row["date"])
  end
end
