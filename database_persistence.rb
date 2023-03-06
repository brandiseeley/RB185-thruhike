require "pry-byebug"
# Direct interaction with Postgres Database via PG::Connection object
# Shouldn't be concerned with validation, should only insert/query/delete
class DatabasePersistence
  @@database = PG.connect(dbname: "thruhike")

  def initialize(alternate_database = nil)
    @@database = PG.connect(dbname: alternate_database) if alternate_database
  end

  def query(statement, *params)
    data = @@database.exec_params(statement, params)
  rescue PG::UniqueViolation => e
    Status.failure(e.message)
  rescue PG::CheckViolation => e
    Status.failure(e.message)
  rescue PG::NotNullViolation => e
    Status.failure(e.message)
  else
    Status.success(data)
  end

  def insert_new_hike(hike)
    user_id = hike.user.id
    start_mileage = hike.start_mileage
    finish_mileage = hike.finish_mileage
    name = hike.name

    sql = <<-SQL
            INSERT INTO hikes
            (user_id, start_mileage, finish_mileage, name)
            VALUES ($1, $2, $3, $4) RETURNING id;
    SQL
    query(sql, user_id, start_mileage, finish_mileage, name)
  end

  def insert_new_point(point)
    hike_id = point.hike.id
    mileage = point.mileage
    date = point.date

    sql = <<-SQL
            INSERT INTO points
            (hike_id, mileage, date)
            VALUES
            ($1, $2, $3);
    SQL

    query(sql, hike_id, mileage, date)
  end

  def insert_new_user(user)
    name = user.name
    user_name = user.user_name
    sql = <<-SQL
            INSERT INTO users
            (name, user_name)
            VALUES
            ($1, $2)
            RETURNING id;
    SQL

    query(sql, name, user_name)
  end

  def delete_hike(hike_id)
    sql = "DELETE FROM hikes WHERE id = $1"
    query(sql, hike_id)
  end

  def delete_point(point_id)
    sql = "DELETE FROM points WHERE id = $1"
    query(sql, point_id)
  end

  def update_hike_name(hike_id, new_name)
    sql = "UPDATE hikes SET name = $1 WHERE id = $2"
    query(sql, new_name, hike_id)
  end

  def update_hike_start_mileage(hike_id, new_start_mileage)
    sql = "UPDATE hikes SET start_mileage = $1 WHERE id = $2"
    query(sql, new_start_mileage, hike_id)
  end

  def update_hike_finish_mileage(hike_id, new_finish_mileage)
    sql = "UPDATE hikes SET finish_mileage = $1 WHERE id = $2"
    query(sql, new_finish_mileage, hike_id)
  end

  def average_mileage_per_day(hike)
    points_attempt = all_points_from_hike(hike.id)
    return points_attempt unless points_attempt.success

    return query("SELECT 0.0") if points_attempt.data.ntuples.zero?

    mileages = points_attempt.data.field_values("mileage")
    return query("SELECT 0.0") if mileages.all? { |mileage| mileage.to_f == hike.start_mileage }

    sql = <<-SQL
          select round( ( max(mileage) - max(start_mileage) ) / 
          CASE
            WHEN min(mileage) = max(start_mileage)
              THEN max(date) - min(date)
            ELSE max(date) - min(date) + 1
          END, 2)

          FROM hikes JOIN points ON hikes.id = points.hike_id  
          WHERE hikes.id = $1;
    SQL
    query(sql, hike.id)
  end

  def mileage_from_finish(hike)
    sql = <<-SQL
          SELECT hikes.finish_mileage - max(points.mileage)
          FROM hikes JOIN points
          ON hikes.id = points.hike_id
          WHERE hikes.id = $1
          GROUP BY hikes.id;
    SQL
    query(sql, hike.id)
  end

  def all_users
    query("SELECT * FROM users;")
  end

  def one_user(user_id)
    sql = "SELECT * FROM users WHERE id = $1"
    query(sql, user_id)
  end

  def all_hikes_from_user(user_id)
    sql = "SELECT * FROM hikes WHERE user_id = $1"
    query(sql, user_id)
  end

  def one_hike(hike_id)
    sql = "SELECT * FROM hikes WHERE hikes.id = $1"
    query(sql, hike_id)
  end

  def all_points_from_hike(hike_id)
    sql = "SELECT * FROM points WHERE hike_id = $1"
    query(sql, hike_id)
  end

  def one_point(point_id)
    sql = "SELECT * FROM points WHERE id = $1"
    query(sql, point_id)
  end

  def id_from_user_name(user_name)
    sql = "SELECT id FROM users WHERE user_name = $1"
    query(sql, user_name)
  end

  def number_of_points(hike)
    sql = <<-SQL
          SELECT COUNT(id) FROM points
          WHERE hike_id = $1
    SQL

    query(sql, hike.id)
  end

  def length_of_hike(hike)
    Status.new(true, "okay", hike.finish_mileage - hike.start_mileage)
  end
end

# TODO : Class methods to help construct common types
# The status object that is returned by all DatabasePersistence methods
class Status
  attr_accessor :data, :success, :message

  def initialize(success, message, data)
    @success = success
    @message = message
    @data = data
  end

  def self.success(data = nil)
    new(true, nil, data)
  end

  def self.failure(message)
    new(false, message, nil)
  end
end
