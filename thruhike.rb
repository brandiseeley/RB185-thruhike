require "pg"

require_relative "database_persistence"
require_relative "testing/testable"

include Testable

# Provide ModuleManager instance to each class
module Managable
  def manager
    ModelManager.new
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
  include Managable

  attr_reader :user, :start_mileage, :finish_mileage, :name, :completed, :id

  def initialize(user_object, start_mileage, finish_mileage, name, completed, id = nil)
    @manager = manager

    @user = user_object
    @start_mileage = start_mileage
    @finish_mileage = finish_mileage
    @name = name
    @completed = completed
    @id = id
  end

  def save
    # ??? Is this validation happening where we want it?
    raise(NoMatchingPKError, "Can't initialize new Hike with User ID that doesn't exist") unless @user.id

    status = @manager.insert_new_hike(@user.id,
                                      @start_mileage,
                                      @finish_mileage,
                                      @name,
                                      @completed)
    if status.success
      @id = status.data
    end                                      
    self
  end

  def create_new_point(mileage, date)
    Point.new(self, mileage, date)
  end

  def mark_complete
    @completed = true
    @manager.mark_hike_complete(id)
  end

  def average_mileage_per_day
    @manager.average_mileage_per_day(id)
  end

  def mileage_from_finish
    @manager.mileage_from_finish(id)
  end

  def ==(other)
    user == other.user &&
      start_mileage == other.start_mileage &&
      finish_mileage == other.finish_mileage &&
      name == other.name &&
      completed == other.completed &&
      id == other.id
  end

  def <=>(other)
    name <=> other.name
  end
end

# Creates Point objects that can be saved to database, dependent on having Hike object
class Point
  include Managable

  attr_reader :hike, :mileage, :date

  def initialize(hike_object, mileage, date)
    @manager = manager

    @hike = hike_object
    @mileage = mileage
    @date = date
  end

  def save
    raise(NoMatchingPKError, "Can't initialize new Point with Hike ID that doesn't exist") unless @hike.id

    status = @manager.insert_new_point(@hike.id, @mileage, @date)
    if status.success
      @id = status.data
    end
    self
  end

  def ==(other)
    hike == other.hike &&
      mileage == other.mileage &&
      date == other.date
  end

  def <=>(other)
    date <=> other.date
  end

  def to_s
    "Hike: #{hike}, Mileage: #{mileage}, Date: #{date}"
  end
end

# Creates User objects that can be saved to database
class User
  include Managable

  attr_reader :name, :user_name, :id

  # TODO: The way id works now, if we resave a user, they will get a new id and the older user will be left
  def initialize(name, user_name, id = nil)
    @manager = manager

    @name = name
    @user_name = user_name
    @id = id
  end

  def save
    status = @manager.insert_new_user(@name, @user_name)
    if status.success
      @id = status.data
    end
    self
  end

  def to_s
    "name: #{@name}, user_name: #{@user_name}, id: #{id}"
  end

  def ==(other)
    name == other.name &&
      user_name == other.user_name &&
      id == other.id
  end

  def <=>(other)
    name <=> other.name
  end
end
