require "pg"

module Testable
  def reset_database
    @database = PG.connect(dbname: "thruhike")
    schema_sql = File.open("./testing/test_schema.sql", "rb") { |file| file.read }
    @database.exec(schema_sql)
  end

  def insert_test_data
    @user1 = User.new("User One", "user_one_1").save
    @incomplete_hike_zero_start = Hike.new(@user1, 0.0, 2194.3, "Incomplete Hike Zero Start", false).save
    @incomplete_hike_zero_start.create_new_point(Date.new(2022, 4, 10), 8.1).save
    @incomplete_hike_zero_start.create_new_point(Date.new(2022, 4, 11), 15.7).save

    @user2 = User.new("User Two", "user_two_2").save
    @complete_hike_non_zero_start = Hike.new(@user2, 50.0, 150.0, "Complete Hike Non-zero Start", false).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2021, 12, 29), 58.3).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2021, 12, 30), 71.3).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2021, 12, 31), 80.85).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2022, 1, 1), 89.85).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2022, 1, 2), 104.6).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2022, 1, 3), 124.6).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2022, 1, 4), 124.6).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2022, 1, 5), 135.2).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2022, 1, 6), 135.2).save
    @complete_hike_non_zero_start.create_new_point(Date.new(2022, 1, 7), 150.0).save
    @complete_hike_non_zero_start.mark_complete

    @second_hike_incomplete = Hike.new(@user2, 0.0, 30.0, "Short Hike Incomplete", false).save
    @second_hike_incomplete.create_new_point(Date.new(2023, 1, 12), 4.2).save
    @second_hike_incomplete.create_new_point(Date.new(2023, 1, 13), 9.3).save
  end
end




# olivier = User.new("Olivier", "ochatot").save

# p appalachian.average_mileage_per_day # => 8.56
# p appalachian.mileage_from_finish
