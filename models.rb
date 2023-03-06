require "pg"

# Error thrown when Dependent object hasn't been saved. Ex: Create Hike without saved User
class NoMatchingPKError < StandardError
  def initialize(msg = "Can't initialize object with reference to Primary Key that isn't saved")
    super
  end
end

# Creates Hike objects that can be saved to database, dependent on having User object
class Hike
  attr_reader :user, :start_mileage, :finish_mileage, :name
  attr_accessor :id

  def initialize(user_object, start_mileage, finish_mileage, name, id = nil)
    @user = user_object
    @start_mileage = start_mileage
    @finish_mileage = finish_mileage
    @name = name
    @id = id
  end

  def create_new_point(mileage, date)
    Point.new(self, mileage, date)
  end

  def ==(other)
    user == other.user &&
      start_mileage == other.start_mileage &&
      finish_mileage == other.finish_mileage &&
      name == other.name &&
      id == other.id
  end

  def <=>(other)
    name <=> other.name
  end
end

# Creates Point objects that can be saved to database, dependent on having Hike object
class Point
  # @manager = ModelManager.new

  attr_reader :hike, :mileage, :date
  attr_accessor :id

  def initialize(hike_object, mileage, date, id = nil)
    @hike = hike_object
    @mileage = mileage
    @date = date
    @id = id
  end

  def ==(other)
    hike == other.hike &&
      mileage == other.mileage &&
      date == other.date
  end

  def <=>(other)
    other.date <=> date
  end

  def to_s
    "Hike: #{hike}, Mileage: #{mileage}, Date: #{date}, ID: #{id}"
  end
end

# Creates User objects that can be saved to database
class User
  # @manager = ModelManager.new

  attr_reader :name, :user_name
  attr_accessor :id

  # TODO: The way id works now, if we resave a user, they will get a new id and the older user will be left
  def initialize(name, user_name, id = nil)
    @name = name
    @user_name = user_name
    @id = id
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
