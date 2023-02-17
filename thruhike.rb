require "pg"

require_relative "database_persistence"
require_relative "testable"

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

  attr_reader :id

  def initialize(user, start_mileage, finish_mileage, name, completed)
    @storage = storage
    @user = user
    @start_mileage = start_mileage
    @finish_mileage = finish_mileage
    @name = name
    @completed = completed
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

  def average_mileage_per_day
    @storage.average_mileage_per_day(id)
  end

  def distance_from_finish

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

  attr_reader :id

  def initialize(name)
    @storage = storage
    @name = name
  end

  def save
    @id = @storage.insert_new_user(@name) # create new User and return id
    self
  end
end


# Reminder : test_thruhike.rb will fail if these tests aren't commented out
# Testable.reset_database

# brandi = User.new("Brandi").save
# appalachian = Hike.new(brandi, 0.0, 2193.0, "Appalachian Trail", false).save
# appalachian.create_new_point(Date.new(2022, 4, 10), 8.1).save
# appalachian.create_new_point(Date.new(2022, 4, 11), 15.7).save
# appalachian.create_new_point(Date.new(2022, 4, 12), 26.3).save
# appalachian.create_new_point(Date.new(2022, 4, 13), 32.4).save
# appalachian.create_new_point(Date.new(2022, 4, 14), 42.8).save

# p appalachian.average_mileage_per_day # => 8.56
