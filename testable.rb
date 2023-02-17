require "pg"

module Testable
  def reset_database
    @database = PG.connect(dbname: "thruhike")
    schema_sql = File.open("./testing/test_schema.sql", "rb") { |file| file.read }
    @database.exec(schema_sql)
  end
end
