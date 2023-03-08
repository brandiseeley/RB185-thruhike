require_relative "models"
require_relative "database_persistence"

# Returns a Status object that will contain correctly formatted objects
# Or bad status if query/task was unsuccessful
class ModelManager
  @@database = DatabasePersistence.new

  def initialize(alternate_database = nil)
    @@database = DatabasePersistence.new(alternate_database) if alternate_database
  end

  # Fetching Methods
  def one_user(user_id)
    attempt = @@database.one_user(user_id)
    return Status.failure("Unable to fetch user") unless attempt.success

    Status.success(construct_user(attempt.data.first))
  end

  def all_users
    attempt = @@database.all_users
    return Status.failure("Unable to fetch users") unless attempt.success

    users = attempt.data.map do |user_data|
      construct_user(user_data)
    end.sort

    Status.success(users)
  end

  def one_hike(hike_id)
    attempt = @@database.one_hike(hike_id)

    return Status.failure("Unable to fetch hike") unless attempt.success

    if attempt.data.ntuples.positive?
      Status.success(construct_hike(attempt.data.first))
    else
      Status.failure("Unable to fetch hike")
    end
  end

  def all_hikes_from_user(user_id)
    attempt = @@database.all_hikes_from_user(user_id)
    return attempt unless attempt.success

    hikes = attempt.data.map do |hike_data|
      construct_hike(hike_data)
    end.sort

    Status.success(hikes)
  end

  def one_point(hike, point_id)
    point_attempt = @@database.one_point(point_id)
    return point_attempt unless point_attempt.success

    return Status.failure("Unable to fetch point") unless point_attempt.data.ntuples.positive?

    Status.success(construct_point(point_attempt.data.first, hike))
  end

  def all_points_from_hike(hike)
    points_attempt = @@database.all_points_from_hike(hike)
    return points_attempt unless points_attempt.success

    points = points_attempt.data.map do |point_data|
      construct_point(point_data, hike)
    end.sort

    Status.success(points)
  end

  def all_goals_from_hike(hike)
    goals_attempt = @@database.all_goals_from_hike(hike)
    return goals_attempt unless goals_attempt.success

    goals = goals_attempt.data.map do |goal_data|
      construct_goal(goal_data)
    end.sort

    Status.success(goals)
  end

  def id_from_user_name(user_name)
    id_attempt = @@database.id_from_user_name(user_name)
    return id_attempt unless id_attempt.success

    id = id_attempt.data.values.flatten.first.to_i
    return Status.success(nil) if id.zero?
    Status.success(id)
  end

  # Inserting Methods

  # Returns id assigned by database
  def insert_new_user(user)
    attempt = @@database.insert_new_user(user)
    return attempt unless attempt.success

    id = attempt.data.values.flatten.first.to_i
    user.id = id
    Status.success(id)
  end

  # Returns id assigned by database
  def insert_new_hike(hike)
    validate_attempt = validate_hike_details(hike)
    return validate_attempt unless validate_attempt.success

    validity = validate_attempt.data
    return Status.failure(validity.reason) unless validity.valid

    insert_attempt = @@database.insert_new_hike(hike)
    return Status.failure("Unable to create new hike") unless insert_attempt.success

    id = insert_attempt.data.values.flatten.first.to_i
    hike.id = id
    Status.success(id)
  end

  # Returns id assigned by database
  def insert_new_point(point)
    validate_attempt = validate_point_details(point)
    return validate_attempt unless validate_attempt.success

    validity = validate_attempt.data
    return Status.failure(validity.reason) unless validity.valid

    insert_attempt = @@database.insert_new_point(point)
    return Status.failure("Unable to create new point") unless insert_attempt.success

    id = insert_attempt.data.values.flatten.first.to_i
    point.id = id
    Status.success(id)
  end

  def insert_new_goal(user, goal)
    validate_attempt = validate_goal_details(goal, goal.hike)
    return validate_attempt unless validate_attempt.success

    validity = validate_attempt.data
    return Status.failure(validity.reason) unless validity.valid

    insert_attempt = @@database.insert_new_goal(goal)
    return Status.failure("Unable to create new goal") unless insert_attempt.success

    id = insert_attempt.data.values.flatten.first.to_i
    goal.id = id
    Status.success(id)
  end

  # Deleting Methods

  def delete_hike(hike, user)
    delete_attempt = @@database.delete_hike(hike)

    delete_attempt.success ? Status.success : Status.failure("There was an error editing this hike")
  end

  def delete_point(user, hike, point_id)
    validate_attempt = validate_point_to_delete(user, hike, point_id)
    return validate_attempt unless validate_attempt.success

    validity = validate_attempt.data
    return Status.failure(validity.reason) unless validity.valid

    delete_attempt = @@database.delete_point(point_id)

    delete_attempt.success ? Status.success : Status.failure("There was an error editing this hike")
  end

  def delete_goal(user, hike, goal_id)
    # TODO : Validate details (user owns goal, goal belongs to current hike)

    goal_belongs_to_hike_check = validate_goal_belongs_to_hike(hike, goal_id)
    return goal_belongs_to_hike_check unless goal_belongs_to_hike_check.success

    goal_validity = goal_belongs_to_hike_check.data
    return Status.failure(goal_validity.reason) unless goal_validity.valid

    delete_attempt = @@database.delete_goal(goal_id)

    delete_attempt.success ? Status.success : Status.failure("There was an error editng this hike")
  end

  # Editing Methods

  def update_hike_details(user, hike, new_hike_name, new_start_mileage, new_finish_mileage)
    validate_attempt = validate_edit_hike_details(user, hike, new_hike_name, new_start_mileage, new_finish_mileage)
    return validate_attempt unless validate_attempt.success

    validity = validate_attempt.data
    return Status.failure(validity.reason) unless validity.valid

    name_attempt = @@database.update_hike_name(hike, new_hike_name)
    start_attempt = @@database.update_hike_start_mileage(hike, new_start_mileage)
    finish_attempt = @@database.update_hike_finish_mileage(hike, new_finish_mileage)

    all_success = name_attempt.success && start_attempt.success && finish_attempt.success

    return Status.failure("There was an error editing this hike") unless all_success

    Status.success
  end

  # Statistic Methods
  # TODO : HikeStats doesn't do any validation
  def hike_stats(hike)
    HikeStats.new(hike, self)
  end

  def average_mileage_per_day(hike)
    attempt = @@database.average_mileage_per_day(hike)
    return attempt unless attempt.success

    Status.success(attempt.data.values.flatten.first.to_f)
  end

  def mileage_from_finish(hike)
    number_of_points_status = @@database.number_of_points(hike)
    return number_of_points_status unless number_of_points_status.success

    if number_of_points_status.data.values.first.first.to_i.zero?
      length_attempt = @@database.length_of_hike(hike)
      return length_attempt unless length_attempt.success
      Status.success(length_attempt.data)
    else
      from_finish_attempt = @@database.mileage_from_finish(hike)
      return from_finish_attempt unless from_finish_attempt.success

      Status.success(from_finish_attempt.data.values.flatten.first.to_f)
    end
  end

  # Constructor Methods

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
             row["id"].to_i)
  end

  def construct_point(row, hike)
    Point.new(hike,
              row["mileage"].to_f,
              Date.parse(row["date"]).to_date,
              row["id"].to_i)
  end

  def construct_goal(row)
    Goal.new(Date.parse(row["date"]).to_date,
             row["mileage"].to_f,
             row["description"],
             row["hike_id"].to_i,
             row["id"].to_i)
  end

  private

  # TODO : Rename from Validate -> Check, assert, etc?

  # Validation Methods
  # Returns either a Status failure or a Status success with a ValidationResult object as it's data

  def validate_point_to_delete(user, hike, point_id)
    point_attempt = one_point(hike, point_id)
    unless point_attempt.success
      point_attempt.message = "Permission denied, unable to edit hike"
      return point_attempt
    end

    # TODO : Check hike owns points earlier 
    # point = point_attempt.data

    # hike_owns_point_attempt = validate_hike_owns_point(point.hike.id, point_id)
    # return hike_owns_point_attempt unless hike_owns_point_attempt.success

    Status.success(ValidationResult.valid)
  end

  def validate_edit_hike_details(user, hike, new_hike_name, new_start_mileage, new_finish_mileage)
    unless non_negative?(new_start_mileage, new_finish_mileage)
      return Status.success(ValidationResult.invalid("Mileages must be non-negative"))
    end

    unless finish_greater_than_start?(new_start_mileage, new_finish_mileage)
      return Status.success(ValidationResult.invalid("Finishing mileage must be greater than starting mileage"))
    end

    all_hikes_attempt = all_hikes_from_user(user.id)
    return all_hikes_attempt unless all_hikes_attempt.success

    all_hikes = all_hikes_attempt.data

    if all_hikes.any? { |other_hike| new_hike_name == other_hike.name && hike.id != other_hike.id }
      return Status.success(ValidationResult.invalid("You already have a hike titled '#{new_hike_name}'"))
    end

    validate_mileage_confict_with_existing_points(hike, new_start_mileage, new_finish_mileage)
  end

  def validate_point_details(point)
    points_attempt = all_points_from_hike(point.hike)
    return points_attempt unless points_attempt.success

    points = points_attempt.data
    hike = point.hike

    if points.any? { |p| point.date === p.date }
      return Status.success(ValidationResult.invalid("Each day may only have one point"))
    end

    unless linear_mileage?(point.date, point.mileage, points, hike)
      return Status.success(ValidationResult.invalid("Mileage must be ascending or equal from one day to a following day"))
    end

    Status.success(ValidationResult.valid)
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

  def validate_goal_details(goal, hike)
    unless non_negative?(goal.mileage)
      return Status.success(ValidationResult.invalid("Mileage must be non-negative"))
    end

    all_points_attempt = all_points_from_hike(hike)
    return all_points_attempt unless all_points_attempt.success

    all_points = all_points_attempt.data

    if !all_points.empty? && all_points.last.date > goal.date
      return Status.success(ValidationResult.invalid("Date must be past first existing point date"))
    end

    Status.success(ValidationResult.valid)
  end

  def validate_goal_belongs_to_hike(hike, goal_id)
    all_goals_from_hike_attempt = all_goals_from_hike(hike)
    return all_goals_from_hike_attempt unless all_goals_from_hike_attempt.success

    all_goals = all_goals_from_hike_attempt.data
    if all_goals.none? { |goal| goal.id == goal_id }
      return Status.success(ValidationResult.invalid("Goal doesn't belong to current hike"))
    end

    Status.success(ValidationResult.valid)
  end

  def validate_duplicate_name(hike_name, user)
    all_hikes_attempt = all_hikes_from_user(user.id)
    return all_hikes_attempt unless all_hikes_attempt.success

    all_hikes = all_hikes_attempt.data
    return Status.success(ValidationResult.valid) if all_hikes.none? { |hike| hike.name == hike_name }

    Status.success(ValidationResult.invalid("You already have a hike titled '#{hike_name}'"))
  end



  # def validate_hike_owns_point(hike_id, point_id)
  #   points_attempt = all_points_from_hike(hike_id)
  #   return points_attempt unless points_attempt.success

  #   points = points_attempt.data
  #   if points.any? { |point| point.id == point_id.to_i }
  #     Status.success(ValidationResult.invalid("Permission denied, unable to edit hike"))
  #   else
  #     Status.success(ValidationResult.valid)
  #   end
  # end

  def validate_mileage_confict_with_existing_points(hike, start_mileage, finish_mileage)
    all_points_status = all_points_from_hike(hike)
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

  # Helper Methods

  def to_date(string)
    Date.parse(string)
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

# Returns statistics for a particular hike packaged into an object
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
