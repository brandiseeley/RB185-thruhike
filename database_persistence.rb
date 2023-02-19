require "pry-byebug"
# Direct interaction with Postgres Database via PG::Connection object
# Shouldn't be concerned with validation, should only insert/query/delete
class DatabasePersistence
  # Note: Scalar queries should return appropriate values, float, int, etc
  #       Multi-row queries should return raw PG::Result object
  #       Single-row queries should return single row values
  def initialize
    @database = PG.connect(dbname: "thruhike")
  end

  def query(statement, *params)
    # binding.pry
    begin
      data = @database.exec_params(statement, params)
    rescue PG::UniqueViolation => error
      return LogStatus.new(false, error.message)
    rescue PG::CheckViolation => error
      return LogStatus.new(false, error.message)
    else
      return LogStatus.new(true, "Okay", data)
    end
  end

  def insert_new_hike(user_id, start_mileage, finish_mileage, name, completed)
    sql = <<-SQL
            INSERT INTO hikes
            (user_id, start_mileage, finish_mileage, name, completed)
            VALUES
            ($1, $2, $3, $4, $5)
            RETURNING id;
    SQL

    query(sql, user_id, start_mileage, finish_mileage, name, completed)
  end

  def insert_new_point(hike_id, mileage, date)
    sql = <<-SQL
            INSERT INTO points
            (hike_id, mileage, date)
            VALUES
            ($1, $2, $3);
    SQL

    query(sql, hike_id, mileage, date)
  end

  def insert_new_user(name, user_name)
    sql = <<-SQL
            INSERT INTO users
            (name, user_name)
            VALUES
            ($1, $2)
            RETURNING id;
    SQL

    query(sql, name, user_name)
  end

  def average_mileage_per_day(hike_id)
    sql = <<-SQL
          SELECT ROUND(AVG(days_mileage), 2) FROM (
            SELECT CASE
              WHEN (points.mileage - LAG(points.mileage, 1) OVER (ORDER BY date)) IS NULL THEN points.mileage
              ELSE points.mileage - LAG(points.mileage, 1) OVER (ORDER BY date) END AS days_mileage
            FROM points JOIN hikes ON points.hike_id = hikes.id
            WHERE hike_id = $1
            ORDER BY date ) AS mileage_per_day;
    SQL
    query(sql, hike_id)
  end

  def mileage_from_finish(hike_id)
    sql = <<-SQL
          SELECT hikes.finish_mileage - max(points.mileage)
          FROM hikes JOIN points
          ON hikes.id = points.hike_id
          WHERE hikes.id = $1
          GROUP BY hikes.id;
    SQL
    query(sql, hike_id)
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

  def mark_hike_complete(hike_id)
    sql = "UPDATE hikes SET completed = true WHERE id = $1"
    query(sql, hike_id)
  end
end

class LogStatus
  attr_reader :success, :message, :data
  attr_writer :data

  def initialize(success, message, data=nil)
    @success = success
    @message = message
    @data = data
  end
end
