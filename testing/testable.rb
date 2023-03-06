require "pg"
require_relative "../model_manager"
require_relative "../models"

class TestData
  def self.reset_database
    @database = PG.connect(dbname: "thruhike")
    schema_sql = File.open("../schema.sql", "rb") { |file| file.read }
    @database.exec(schema_sql)
  end

  def self.insert_test_data
    manager = ModelManager.new

    @user1 = User.new("User One", "user_one_1")
    manager.insert_new_user(@user1)

    @incomplete_hike_zero_start = Hike.new(@user1, 0.0, 2194.3, "Incomplete Hike Zero Start")
    manager.insert_new_hike(@incomplete_hike_zero_start)

    manager.insert_new_point(Point.new(@incomplete_hike_zero_start, 8.1, Date.new(2022, 4, 10)))
    manager.insert_new_point(Point.new(@incomplete_hike_zero_start, 15.7, Date.new(2022, 4, 11)))

    @user2 = User.new("User Two", "user_two_2")
    manager.insert_new_user(@user2)

    @complete_hike_non_zero_start = Hike.new(@user2, 50.0, 150.0, "Complete Hike Non-zero Start")
    manager.insert_new_hike(@complete_hike_non_zero_start)

    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 58.3, Date.new(2021, 12, 29)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 71.3, Date.new(2021, 12, 30)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 80.85, Date.new(2021, 12, 31)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 89.85, Date.new(2022, 1, 1)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 104.6, Date.new(2022, 1, 2)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 124.6, Date.new(2022, 1, 3)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 124.6, Date.new(2022, 1, 4)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 135.2, Date.new(2022, 1, 5)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 135.2, Date.new(2022, 1, 6)))
    manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 150.0, Date.new(2022, 1, 7)))

    @second_hike_incomplete = Hike.new(@user2, 0.0, 30.0, "Short Hike Incomplete")
    manager.insert_new_hike(@second_hike_incomplete)

    manager.insert_new_point(Point.new(@second_hike_incomplete, 4.2, Date.new(2023, 1, 12)))
    manager.insert_new_point(Point.new(@second_hike_incomplete, 9.3, Date.new(2023, 1, 13)))
  end
end


TestData.reset_database
TestData.insert_test_data