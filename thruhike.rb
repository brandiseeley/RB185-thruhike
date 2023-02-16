require "pg"

require_relative "database_persistence"

module Database
  def storage
    @storage = DatabasePersistence.new
  end
end

class NoMatchingPKError < StandardError
  def initialize(msg="Can't initialize object with reference to Primary Key that isn't saved")
    super
  end
end

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
    raise NoMatchingPKError.new("Can't initialize new Hike with User ID that doesn't exist") unless @user.id
    @id = @storage.insert_new_hike(@user.id, 
                                   @start_mileage, 
                                   @finish_mileage, 
                                   @name, 
                                   @completed) # create new Hike & return id
    self
  end

  def create_new_point(date, mileage)
    Point.new(self, mileage, date)
  end
end

class Point
  include Database
  
  def initialize(hike, mileage, date)
    @storage = storage
    @hike = hike
    @mileage = mileage
    @date = date
  end
  
  def save
    raise NoMatchingPKError.new("Can't initialize new Point with Hike ID that doesn't exist") unless @hike.id
    @id = @storage.insert_new_point(@hike.id, @mileage, @date)
    self
  end
end

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

# Mile	Percent distance	Miles to go	Night	Percent time	Date	Day's miles
# 8.1	   0.37%	   2186.2	  2	1.18%	    April 10, 2022	   8.1
# 15.7	 0.72%	   2178.6	  3	1.76%	    April 11, 2022	   7.6
# 26.3	 1.20%	   2168	4	  2.35%	      April 12, 2022	   10.6
brandi = User.new("Brandi").save
appalachian = Hike.new(brandi, 0.0, 2193.0, "Appalachian Trail", false).save
appalachian.create_new_point(Date.new(2022, 4, 10), 8.1).save
appalachian.create_new_point(Date.new(2022, 4, 11), 15.7).save

sql = <<-SQL
        SELECT max(users.name), hikes.name, string_agg(points.mileage::text, ', ') FROM hikes
        JOIN points
        ON hikes.id = points.hike_id
        JOIN users
        ON hikes.user_id = users.id
        GROUP BY hikes.id;
      SQL
