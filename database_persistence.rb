# Direct interaction with Postgres Database via PG::Connection object
class DatabasePersistence
  def initialize
    @database = PG.connect(dbname: "thruhike")
  end

  def query(statement, *params)
    @database.exec_params(statement, params)
  end

  def insert_new_hike(user_id, start_mileage, finish_mileage, name, completed)
    sql = <<-SQL
            INSERT INTO hikes
            (user_id, start_mileage, finish_mileage, name, completed)
            VALUES
            ($1, $2, $3, $4, $5)
            RETURNING id
    SQL

    query(sql, user_id, start_mileage, finish_mileage, name, completed).values.flatten.first.to_i
  end

  def insert_new_point(hike_id, mileage, date)
    sql = <<-SQL
            INSERT INTO points
            (hike_id, mileage, date)
            VALUES
            ($1, $2, $3)
    SQL

    query(sql, hike_id, mileage, date).values.flatten.first.to_i
  end

  def insert_new_user(name, user_name)
    sql = <<-SQL
            INSERT INTO users
            (name, user_name)
            VALUES
            ($1, $2)
            RETURNING id
    SQL

    query(sql, name, user_name).values.flatten.first.to_i
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
    scalar_query_to_float(query(sql, hike_id))
  end

  def mileage_from_finish(hike_id)
    sql = <<-SQL
          SELECT hikes.finish_mileage - max(points.mileage)
          FROM hikes JOIN points
          ON hikes.id = points.hike_id
          WHERE hikes.id = $1
          GROUP BY hikes.id;
    SQL
    result = query(sql, hike_id)
    scalar_query_to_float(result)
  end

  private

  def scalar_query_to_float(result)
    result.values.first.first.to_f
  end
end
