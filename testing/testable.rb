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

    manager.insert_new_goal(@user2, Goal.new(Date.new(2023, 1, 17), 30.0, "Finish Hike", @second_hike_incomplete))
  end

  def self.fun_stats
    manager = ModelManager.new

    brandi = User.new("Brandi", "seeleybrandi")
    manager.insert_new_user(brandi)

    appalachian_trail = Hike.new(brandi, 0.0, 2194.3, "Appalachian Trail")
    manager.insert_new_hike(appalachian_trail)

    finish = Goal.new(Date.new(2022, 9, 25), 2194.3, "Summit Katahdin", appalachian_trail)
    harpers_ferry = Goal.new(Date.new(2022, 7, 3), 1032.7, "Harper's Ferry", appalachian_trail)
    manager.insert_new_goal(brandi, finish)
    manager.insert_new_goal(brandi, harpers_ferry)
    manager.insert_new_point(Point.new(appalachian_trail, 8.1, Date.new(2022, 4, 10)))
    manager.insert_new_point(Point.new(appalachian_trail, 15.7, Date.new(2022, 4, 11)))
    manager.insert_new_point(Point.new(appalachian_trail, 26.3, Date.new(2022, 4, 12)))
    manager.insert_new_point(Point.new(appalachian_trail, 32.4, Date.new(2022, 4, 13)))
    manager.insert_new_point(Point.new(appalachian_trail, 42.8, Date.new(2022, 4, 14)))
    manager.insert_new_point(Point.new(appalachian_trail, 50.1, Date.new(2022, 4, 15)))
    manager.insert_new_point(Point.new(appalachian_trail, 50.1, Date.new(2022, 4, 16)))
    manager.insert_new_point(Point.new(appalachian_trail, 53.4, Date.new(2022, 4, 17)))
    manager.insert_new_point(Point.new(appalachian_trail, 58.2, Date.new(2022, 4, 18)))
    manager.insert_new_point(Point.new(appalachian_trail, 62.9, Date.new(2022, 4, 19)))
    manager.insert_new_point(Point.new(appalachian_trail, 65.6, Date.new(2022, 4, 20)))
    manager.insert_new_point(Point.new(appalachian_trail, 69.2, Date.new(2022, 4, 21)))
    manager.insert_new_point(Point.new(appalachian_trail, 73.7, Date.new(2022, 4, 22)))
    manager.insert_new_point(Point.new(appalachian_trail, 81, Date.new(2022, 4, 23)))

  end
end


TestData.reset_database
TestData.insert_test_data
TestData.fun_stats