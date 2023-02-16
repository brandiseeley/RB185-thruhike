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

  def insert_new_user(name)
    sql = <<-SQL
            INSERT INTO users
            (name)
            VALUES
            ($1)
            RETURNING id
          SQL
    
    query(sql, name).values.flatten.first.to_i
  end
end
