require_relative "models"
require_relative "database_persistence"

# Returns a LogStatus object that will contain correctly formatted objects
# Or bad status if query was unsuccessful
class ModelManager
  @@database = DatabasePersistence.new

  def initialize(alternate_database = nil)
    @@database = DatabasePersistence.new(alternate_database) if alternate_database
  end

  # Fetching methods
  def all_users
    attempt = @@database.all_users

    if attempt.success
      new_data = attempt.data.map do |user_data|
        construct_user(user_data)
      end.sort

      attempt.data = new_data
    end
    attempt
  end

  def one_user(user_id)
    attempt = @@database.one_user(user_id)

    attempt.data = construct_user(attempt.data.first) if attempt.success
    attempt
  end

  def all_hikes_from_user(user_id)
    attempt = @@database.all_hikes_from_user(user_id)

    if attempt.success
      new_data = attempt.data.map do |hike_data|
        construct_hike(hike_data)
      end.sort

      attempt.data = new_data
    end
    attempt
  end

  def one_hike(hike_id)
    attempt = @@database.one_hike(hike_id)

    if attempt.data.ntuples.positive?
      attempt.data = construct_hike(attempt.data.first)
    else
      attempt.success = false
    end
    attempt
  end

  def all_points_from_hike(hike_id)
    attempt = @@database.all_points_from_hike(hike_id)

    if attempt.success
      hike_object = one_hike(hike_id).data
      points_data = attempt.data

      new_data = points_data.map do |point_data|
        construct_point(point_data, hike_object)
      end.sort

      attempt.data = new_data
    end
    attempt
  end

  def one_point(point_id)
    attempt = @@database.one_point(point_id)

    if attempt.data.ntuples.positive?
      hike_id = attempt.data.first["hike_id"].to_i
      hike = one_hike(hike_id)
      attempt.data = construct_point(attempt.data.first, hike)
    else
      attempt.success = false
    end
    attempt
  end

  # Statistic Methods
  def average_mileage_per_day(hike)
    attempt = @@database.average_mileage_per_day(hike)
    attempt.data = attempt.data.values.flatten.first.to_f if attempt.success
    attempt
  end

  def mileage_from_finish(hike)
    number_of_points = @@database.number_of_points(hike)
    if number_of_points.data.values.first.first.to_i.zero?
      LogStatus.new(true, "okay", @@database.length_of_hike(hike).data)
    else
      attempt = @@database.mileage_from_finish(hike)
      attempt.data = attempt.data.values.flatten.first.to_f if attempt.success
      attempt
    end
  end

  # Inserting/Altering Methods
  def mark_hike_complete(hike)
    @@database.mark_hike_complete(hike)
  end

  # Returns id assigned by database
  def insert_new_hike(hike)
    validity_status = validate_hike_details(hike)
    return validity_status unless validity_status.success

    attempt = @@database.insert_new_hike(hike)

    if attempt.success
      attempt.data = attempt.data.values.flatten.first.to_i
      hike.id = attempt.data
    end
    attempt
  end

  # Returns id assigned by database
  def insert_new_point(point)
    validity_status = validate_point_details(point)
    return validity_status unless validity_status.success

    attempt = @@database.insert_new_point(point)

    if attempt.success
      attempt.data = attempt.data.values.flatten.first.to_i
      point.id = attempt.data
    end
    attempt
  end

  # Insert new user and update ID with id given by db
  def insert_new_user(user)
    attempt = @@database.insert_new_user(user)

    if attempt.success
      attempt.data = attempt.data.values.flatten.first.to_i
      user.id = attempt.data
    end
    attempt
  end

  def delete_hike(hike_id)
    @@database.delete_hike(hike_id)
  end

  def delete_point(point_id)
    @@database.delete_point(point_id)
  end

  def update_hike_name(hike_id, new_name)
    @@database.update_hike_name(hike_id, new_name)
  end

  def update_hike_start_mileage(hike_id, new_start_mileage)
    @@database.update_hike_start_mileage(hike_id, new_start_mileage)
  end

  def update_hike_finish_mileage(hike_id, new_finish_mileage)
    @@database.update_hike_finish_mileage(hike_id, new_finish_mileage)
  end

  def hike_stats(hike)
    HikeStats.new(hike, self)
  end

  private

  # Validation Helpers
  def validate_hike_details(hike)
    status = LogStatus.new(true, "okay", nil)

    if !non_negative?(hike.start_mileage, hike.finish_mileage)
      status.message = "Mileages must be non-negative"
      status.success = false
    elsif !finish_greater_than_start?(hike.start_mileage, hike.finish_mileage)
      status.message = "Finishing mileage must be greater than starting mileage"
      status.success = false
    elsif duplicate_name?(hike.name, hike.user)
      status.message = "You already have a hike titled '#{hike.name}'"
      status.success = false
    end

    status
  end

  def validate_point_details(point)
    status = LogStatus.new(true, "okay", nil)

    points = all_points_from_hike(point.hike.id).data
    hike = point.hike

    # if points.any? { |p| to_date(point.date) === p.date }
    if points.any? { |p| point.date === p.date }
      status.message = "Each day may only have one point"
      status.success = false
    elsif !validate_linear_mileage?(point.date, point.mileage, points, hike)
      status.message = "Mileage must be ascending or equal from one day to a following day"
      status.success = false
    elsif !user_owns_hike?(hike.user.id, point.hike.id)
      status.message = "Permission to edit this hike denied"
      status.success = false
    end

    status
  end

  def validate_linear_mileage?(date, mileage, points, hike)
    # date = to_date(date)
  
    mileage_before = hike.start_mileage
    
    points.reverse_each do |point|
      if point.date <= date
        mileage_before = point.mileage
      else
        break
      end
    end
    
    mileage_after = hike.finish_mileage
  
    points.each do |point|
      if point.date > date
        mileage_after = point.mileage
      else
        break
      end
    end
  
    (mileage_before..mileage_after).cover?(mileage)
  end

  def user_owns_hike?(user_id, hike_id)
    all_hikes_status = all_hikes_from_user(user_id)
    if all_hikes_status.success
      all_hikes_status.data.any? { |hike| hike.id == hike_id.to_i }
    else
      false
    end
  end
 
  def to_date(string)
    Date.parse(string)
  end

  def non_negative?(*numbers)
    numbers.all? { |n| n.to_f >= 0 }
  end

  def finish_greater_than_start?(start, finish)
    finish.to_f > start.to_f
  end

  def duplicate_name?(hike_name, user)
    all_hikes = all_hikes_from_user(user.id).data
    all_hikes.any? { |hike| hike.name == hike_name }
  end


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
              DateTime.parse(row["date"]).to_date,
              row["id"].to_i)
  end
end

# Returns statistics for a particular hike packages into an object
class HikeStats
  attr_reader :average_mileage_per_day, :mileage_from_finish
  def initialize(hike, manager)
    # TODO : Handle bad status
    @average_mileage_per_day = manager.average_mileage_per_day(hike).data
    @mileage_from_finish = manager.mileage_from_finish(hike).data
  end
end
