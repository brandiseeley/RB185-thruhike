require_relative "models"
require_relative "database_persistence"

# Returns a Status object that will contain correctly formatted objects
# Or bad status if query/task was unsuccessful
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
    return attempt unless attempt.success

    attempt.data = construct_user(attempt.data.first)
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

    return attempt unless attempt.success

    if attempt.data.ntuples.positive?
      Status.success(construct_hike(attempt.data.first))
    else
      Status.failure("Permission denied, unable to edit hike")
    end
  end

  def all_points_from_hike(hike_id)
    attempt = @@database.all_points_from_hike(hike_id)

    return attempt unless attempt.success

    hike_status = one_hike(hike_id)
    return hike_status unless hike_status.success

    hike_object = hike_status.data
    points_data = attempt.data

    attempt.data = points_data.map do |point_data|
      construct_point(point_data, hike_object)
    end.sort

    attempt
  end

  def one_point(point_id)
    attempt = @@database.one_point(point_id)

    return attempt unless attempt.success

    if attempt.data.ntuples.positive?
      hike_id = attempt.data.first["hike_id"].to_i

      hike_status = one_hike(hike_id)
      return hike_status unless hike_status.success

      hike = hike_status.data

      attempt.data = construct_point(attempt.data.first, hike)
    else
      attempt.success = false
    end
    attempt
  end

  # Statistic Methods
  def average_mileage_per_day(hike)
    attempt = @@database.average_mileage_per_day(hike)
    return attempt unless attempt.success

    attempt.data = attempt.data.values.flatten.first.to_f
    attempt
  end

  def mileage_from_finish(hike)
    number_of_points_status = @@database.number_of_points(hike)
    return number_of_points_status unless number_of_points_status.success

    if number_of_points_status.data.values.first.first.to_i.zero?
      @@database.length_of_hike(hike)
    else
      attempt = @@database.mileage_from_finish(hike)
      return attempt unless attempt.success

      Status.success(attempt.data.values.flatten.first.to_f)
    end
  end

  # Inserting/Altering Methods
  def mark_hike_complete(hike)
    @@database.mark_hike_complete(hike)
  end

  # Returns id assigned by database
  def insert_new_hike(hike)
    attempt_status = validate_hike_details(hike)
    return attempt_status unless attempt_status.success

    validity = attempt_status.data
    return Status.failure(validity.reason) unless validity.valid

    attempt = @@database.insert_new_hike(hike)

    if attempt.success
      attempt.data = attempt.data.values.flatten.first.to_i
      hike.id = attempt.data
    end
    attempt
  end

  # Returns id assigned by database
  def insert_new_point(point)
    attempt_status = validate_point_details(point)
    return attempt_status unless attempt_status.success

    validity = attempt_status.data
    return Status.failure(validity.reason) unless validity.valid

    attempt = @@database.insert_new_point(point)
    return attempt unless attempt.success

    attempt.data = attempt.data.values.flatten.first.to_i
    # TODO : Do I need to return the ID anymore?
    point.id = attempt.data
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

  def delete_hike(hike_id, user)
    attempt_status = validate_hike_to_edit(hike_id, user.id)
    return attempt_status unless attempt_status.success

    validity = attempt_status.data
    return Status.failure(validity.reason) unless validity.valid

    delete_status = @@database.delete_hike(hike_id)

    delete_status.success ? Status.success : Status.failure("There was an error editing this hike")
  end

  def delete_point(user, point_id)
    attempt_status = validate_point_to_delete(user, point_id)
    return attempt_status unless attempt_status.success

    validity = attempt_status.data
    return Status.failure(validity.reason) unless validity.valid

    delete_status = @@database.delete_point(point_id)

    delete_status.success ? Status.success : Status.failure("There was an error editing this hike")
  end

  def update_hike_details(user, hike_id, new_hike_name, new_start_mileage, new_finish_mileage)
    attempt_status = validate_edit_hike_details(user, hike_id, new_hike_name, new_start_mileage, new_finish_mileage)
    return attempt_status unless attempt_status.success

    validity_result = attempt_status.data
    return Status.failure(validity_result.reason) unless validity_result.valid

    name_status = @@database.update_hike_name(hike_id, new_hike_name)
    start_status = @@database.update_hike_start_mileage(hike_id, new_start_mileage)
    finish_status = @@database.update_hike_finish_mileage(hike_id, new_finish_mileage)

    all_success = name_status.success && start_status.success && finish_status.success

    return Status.failure("There was an error editing this hike") unless all_success

    Status.success
  end

  # Out of place
  def hike_stats(hike)
    HikeStats.new(hike, self)
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

  def to_date(string)
    Date.parse(string)
  end

  def validate_hike_to_edit(hike_id, user_id)
    attempt = validate_user_owns_hike(user_id, hike_id)
    return attempt unless attempt.success

    validity = attempt.data
    if validity.valid
      Status.success(ValidationResult.valid)
    else
      Status.success(ValidationResult.invalid("Permission denied, unable to edit hike"))
    end
  end

  def validate_point_to_delete(user, point_id)
    point_attempt = one_point(point_id)
    unless point_attempt.success
      point_attempt.message = "Permission denied, unable to edit hike"
      return point_attempt
    end

    point = point_attempt.data

    user_owns_hike_attempt = validate_user_owns_hike(user.id, point.hike.id)
    return user_owns_hike_attempt unless user_owns_hike_attempt.success

    validity = user_owns_hike_attempt.data
    return Status.success(ValidationResult.invalid(validity.reason)) unless validity.valid

    hike_owns_point_attempt = validate_hike_owns_point(point.hike.id, point_id)
    return hike_owns_point_attempt unless hike_owns_point_attempt.success

    validity = user_owns_hike_attempt.data
    return Status.success(ValidationResult.invalid(validity.reason)) unless validity.valid

    Status.success(ValidationResult.valid)
  end

  def validate_edit_hike_details(user, hike_id, new_hike_name, new_start_mileage, new_finish_mileage)
    unless non_negative?(new_start_mileage, new_finish_mileage)
      return Status.success(ValidationResult.invalid("Mileages must be non-negative"))
    end

    unless finish_greater_than_start?(new_start_mileage, new_finish_mileage)
      return Status.success(ValidationResult.invalid("Finishing mileage must be greater than starting mileage"))
    end

    all_hikes_attempt = all_hikes_from_user(user.id)
    return all_hikes_attempt unless all_hikes_attempt.success

    all_hikes = all_hikes_attempt.data

    if all_hikes.any? { |hike| new_hike_name == hike.name && hike_id != hike.id }
      return Status.success(ValidationResult.invalid("You already have a hike titled '#{new_hike_name}'"))
    end

    validate_mileage_confict_with_existing_points(hike_id, new_start_mileage, new_finish_mileage)
  end

  def validate_point_details(point)
    points_attempt = all_points_from_hike(point.hike.id)
    return points_attempt unless points_attempt.success

    points = points_attempt.data
    hike = point.hike

    if points.any? { |p| point.date === p.date }
      return Status.success(ValidationResult.invalid("Each day may only have one point"))
    end

    unless linear_mileage?(point.date, point.mileage, points, hike)
      return Status.success(ValidationResult.invalid("Mileage must be ascending or equal from one day to a following day"))
    end

    validate_user_owns_hike(hike.user.id, point.hike.id)
  end

  def validate_hike_details(hike)
    unless non_negative?(hike.start_mileage, hike.finish_mileage)
      return Status.success(ValidationResult.invalid("Mileages must be non-negative"))
    end

    unless finish_greater_than_start?(hike.start_mileage, hike.finish_mileage)
      return Status.success(ValidationResult.invalid("Finishing mileage must be greater than starting mileage"))
    end

    validate_duplicate_name(hike.name, hike.user)
  end

  def validate_duplicate_name(hike_name, user)
    all_hikes_attempt = all_hikes_from_user(user.id)
    return all_hikes_attempt unless all_hikes_attempt.success

    all_hikes = all_hikes_attempt.data
    if all_hikes.any? { |hike| hike.name == hike_name }
      Status.success(ValidationResult.invalid("You already have a hike titled '#{hike_name}'"))
    else
      Status.success(ValidationResult.valid)
    end
  end

  def validate_user_owns_hike(user_id, hike_id)
    all_hikes_status = all_hikes_from_user(user_id)
    return all_hikes_status unless all_hikes_status.success

    all_hikes = all_hikes_status.data
    if all_hikes.any? { |hike| hike.id == hike_id.to_i }
      Status.success(ValidationResult.valid)
    else
      Status.success(ValidationResult.invalid("Permission denied, unable to edit hike"))
    end
  end

  def validate_hike_owns_point(hike_id, point_id)
    points_attempt = all_points_from_hike(hike_id)
    return points_attempt unless points_attempt.success

    points = points_attempt.data
    if points.any? { |point| point.id == point_id.to_i }
      Status.success(ValidationResult.invalid("Permission denied, unable to edit hike"))
    else
      Status.success(ValidationResult.valid)
    end
  end

  def validate_mileage_confict_with_existing_points(hike_id, start_mileage, finish_mileage)
    all_points_status = all_points_from_hike(hike_id)
    return all_points_status unless all_points_status.success

    all_points = all_points_status.data
    if all_points.all? do |point|
         (start_mileage.to_f..finish_mileage.to_f).cover?(point.mileage.to_f)
       end
      Status.success(ValidationResult.valid)
    else
      Status.success(ValidationResult.invalid("There are existing points within this mileage range. Either change start and finish mileage or delete conficting points and try again"))
    end
  end

  def linear_mileage?(date, mileage, points, hike)
    mileage_before = hike.start_mileage

    points.reverse_each do |point|
      break unless point.date <= date

      mileage_before = point.mileage
    end

    mileage_after = hike.finish_mileage

    points.each do |point|
      break unless point.date > date

      mileage_after = point.mileage
    end

    (mileage_before..mileage_after).cover?(mileage)
  end

  def non_negative?(*numbers)
    numbers.all? { |n| n.to_f >= 0 }
  end

  def finish_greater_than_start?(start, finish)
    finish.to_f > start.to_f
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

# Contains whether data passed validation checks and a reason if not
class ValidationResult
  attr_accessor :valid, :reason

  def initialize(valid, reason)
    @valid = valid
    @reason = reason
  end

  def self.valid
    new(true, nil)
  end

  def self.invalid(reason)
    new(false, reason)
  end
end
