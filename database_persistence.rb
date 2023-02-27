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
    LogStatus.new(false, e.message)
  rescue PG::CheckViolation => e
    LogStatus.new(false, e.message)
  rescue PG::NotNullViolation => e
    LogStatus.new(false, e.message)
  else
    LogStatus.new(true, "Okay", data)
  end

  def insert_new_hike(hike)
    user_id = hike.user.id
    start_mileage = hike.start_mileage
    finish_mileage = hike.finish_mileage
    name = hike.name
    completed = hike.completed

    sql = <<-SQL
            INSERT INTO hikes
            (user_id, start_mileage, finish_mileage, name, completed)
            VALUES ($1, $2, $3, $4, $5) RETURNING id;
    SQL
    query(sql, user_id, start_mileage, finish_mileage, name, completed)
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

  def average_mileage_per_day(hike)
    sql = <<-SQL
          SELECT ROUND(AVG(days_mileage), 2) FROM (
            SELECT CASE
              WHEN (points.mileage - LAG(points.mileage, 1) OVER (ORDER BY date)) IS NULL THEN points.mileage
              ELSE points.mileage - LAG(points.mileage, 1) OVER (ORDER BY date) END AS days_mileage
            FROM points JOIN hikes ON points.hike_id = hikes.id
            WHERE hike_id = $1
            ORDER BY date ) AS mileage_per_day;
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

  def mileage_from_last_point(point)
    # TODO
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

  def mark_hike_complete(hike)
    sql = "UPDATE hikes SET completed = true WHERE id = $1"
    query(sql, hike.id)
  end

  def number_of_points(hike)
    sql = <<-SQL
          SELECT COUNT(id) FROM points
          WHERE hike_id = $1
    SQL

    query(sql, hike.id)
  end

  def length_of_hike(hike)
    LogStatus.new(true, "okay", hike.finish_mileage - hike.start_mileage)
  end
end

# The status object that is returned by all DatabasePersistence methods
class LogStatus
  attr_reader :success, :message, :data
  attr_writer :data

  def initialize(success, message, data = nil)
    @success = success
    @message = message
    @data = data
  end
end
