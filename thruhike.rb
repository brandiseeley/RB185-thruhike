require "pg"

require_relative "database_persistence"
require_relative "testing/testable"

include Testable

# Provides DatabasePersistence object to classes
module Database
  def storage
    @storage = DatabasePersistence.new
  end
end

# Error thrown when Dependent object hasn't been saved. Ex: Create Hike without saved User
class NoMatchingPKError < StandardError
  def initialize(msg = "Can't initialize object with reference to Primary Key that isn't saved")
    super
  end
end

# Creates Hike objects that can be saved to database, dependent on having User object
class Hike
  include Database

  attr_reader :id, :name, :start_mileage, :finish_mileage

  def initialize(user_object, start_mileage, finish_mileage, name, completed, id = nil)
    @storage = storage

    @user = user_object
    @start_mileage = start_mileage
    @finish_mileage = finish_mileage
    @name = name
    @completed = completed
    @id = id
  end

  def save
    raise(NoMatchingPKError, "Can't initialize new Hike with User ID that doesn't exist") unless @user.id

    @id = @storage.insert_new_hike(@user.id,
                                   @start_mileage,
                                   @finish_mileage,
                                   @name,
                                   @completed)
    self
  end

  def create_new_point(date, mileage)
    Point.new(self, mileage, date)
  end

  def mark_complete
    @completed = true
    @storage.mark_hike_complete(id)
  end

  def average_mileage_per_day
    @storage.average_mileage_per_day(id)
  end

  def mileage_from_finish
    @storage.mileage_from_finish(id)
  end
end

# Creates Point objects that can be saved to database, dependent on having Hike object
class Point
  include Database

  def initialize(hike, mileage, date)
    @storage = storage
    @hike = hike
    @mileage = mileage
    @date = date
  end

  def save
    raise(NoMatchingPKError, "Can't initialize new Point with Hike ID that doesn't exist") unless @hike.id

    @id = @storage.insert_new_point(@hike.id, @mileage, @date)
    self
  end
end

# Creates User objects that can be saved to database
class User
  include Database

  attr_reader :id, :name, :user_name

  # TODO: The way id works now, if we resave a user, they will get a new id and the older user will be left
  def initialize(name, user_name, id = nil)
    @storage = storage
    @name = name
    @user_name = user_name
    @id = id
  end

  def save
    @id = @storage.insert_new_user(@name, @user_name) # create new User and return id
    self
  end

  def to_s
    "name: #{@name}, user_name: #{@user_name}, id: #{id}"
  end
end

Testable.reset_database
Testable.insert_test_data
