require_relative "thruhike"
require_relative "database_persistence"
require "pry-byebug"

# Uses values returned from DatabasePersistence, returns constructed objects
class ModelManager
  def initialize
    @database = DatabasePersistence.new
  end

  # Fetching methods
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
    end.sort
  end

  # Statistic Methods
  def average_mileage_per_day(hike_id)
    @database.average_mileage_per_day(hike_id)
  end

  def mileage_from_finish(hike_id)
    @database.mileage_from_finish(hike_id)
  end

  # Inserting/Altering Methods
  def mark_hike_complete(hike_id)
    @database.mark_hike_complete(hike_id)
  end

  # Returns id assigned by database
  def insert_new_hike(user_id, start_mileage, finish_mileage, name, completed)
    @database.insert_new_hike(user_id, start_mileage, finish_mileage, name, completed)
  end

  # Returns id assigned by database
  def insert_new_point(hike_id, mileage, date)
    @database.insert_new_point(hike_id, mileage, date)
  end

  # Returns id assigned by database
  def insert_new_user(name, user_name)
    @database.insert_new_user(name, user_name)
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
              DateTime.parse(row["date"]).to_date)
  end
end
