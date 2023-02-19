require_relative "thruhike"
require_relative "database_persistence"
require "pry-byebug"

# Returns a LogStatus object that will contain correctly formatted objects
# Or bad status if query was unsuccessful
class ModelManager
  def initialize
    @database = DatabasePersistence.new
  end

  # Fetching methods
  def all_users
    attempt = @database.all_users

    if attempt.success
      new_data = attempt.data.map do |user_data|
        construct_user(user_data)
      end.sort

      attempt.data = new_data
    end
    attempt
  end

  def one_user(user_id)
    attempt = @database.one_user(user_id)

    attempt.data = construct_user(attempt.data.first) if attempt.success
    attempt
  end

  def all_hikes_from_user(user_id)
    attempt = @database.all_hikes_from_user(user_id)

    if attempt.success
      new_data = attempt.data.map do |hike_data|
        construct_hike(hike_data)
      end.sort

      attempt.data = new_data
    end
    attempt
  end

  def one_hike(hike_id)
    attempt = @database.one_hike(hike_id)

    attempt.data = construct_hike(attempt.data.first) if attempt.success
    attempt
  end

  def all_points_from_hike(hike_id)
    attempt = @database.all_points_from_hike(hike_id)

    if attempt.success
      # DANGER DANGER BYPASSING CHECKS???
      hike_object = one_hike(hike_id).data
      points_data = attempt.data

      new_data = points_data.map do |point_data|
        construct_point(point_data, hike_object)
      end.sort

      attempt.data = new_data
    end
    attempt
  end

  # Statistic Methods
  def average_mileage_per_day(hike_id)
    attempt = @database.average_mileage_per_day(hike_id)

    attempt.data = attempt.data.values.first.first.to_f if attempt.success
    attempt
  end

  def mileage_from_finish(hike_id)
    attempt = @database.mileage_from_finish(hike_id)
    attempt.data = attempt.data.values.first.first.to_f if attempt.success
    attempt
  end

  # Inserting/Altering Methods
  def mark_hike_complete(hike_id)
    @database.mark_hike_complete(hike_id)
  end

  # Returns id assigned by database
  def insert_new_hike(user_id, start_mileage, finish_mileage, name, completed)
    attempt = @database.insert_new_hike(user_id, start_mileage, finish_mileage, name, completed)

    attempt.data = attempt.data.values.flatten.first.to_i if attempt.success
    attempt
  end

  # Returns id assigned by database
  def insert_new_point(hike_id, mileage, date)
    attempt = @database.insert_new_point(hike_id, mileage, date)
    attempt.data = attempt.data.values.flatten.first.to_i if attempt.success
    attempt
  end

  # Returns id assigned by database
  def insert_new_user(name, user_name)
    attempt = @database.insert_new_user(name, user_name)
    attempt.data = attempt.data.values.flatten.first.to_i if attempt.success
    attempt
  end

  def hike_stats(hike)
    HikeStats.new(hike, self)
  end

  private

  def construct_user(row)
    User.new(row["name"],
             row["user_name"],
             row["id"].to_i)
  end

  def construct_hike(row)
    user_id = row["user_id"].to_i
    user = one_user(user_id).data
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

class HikeStats
  attr_reader :average_mileage_per_day, :mileage_from_finish
  def initialize(hike, manager)
    # TODO : Handle bad status
    @average_mileage_per_day = manager.average_mileage_per_day(hike.id).data
    @mileage_from_finish = manager.mileage_from_finish(hike.id).data
  end
end
