require "pg"

module Testable
  def reset_database
    @database = PG.connect(dbname: "thruhike")
    schema_sql = File.open("./schema.sql", "rb") { |file| file.read }
    @database.exec(schema_sql)
  end

  def insert_test_data
    @user1 = User.new("User One", "user_one_1").save
    @incomplete_hike_zero_start = Hike.new(@user1, 0.0, 2194.3, "Incomplete Hike Zero Start", false).save
    @incomplete_hike_zero_start.create_new_point(8.1, Date.new(2022, 4, 10)).save
    @incomplete_hike_zero_start.create_new_point(15.7, Date.new(2022, 4, 11)).save

    @user2 = User.new("User Two", "user_two_2").save
    @complete_hike_non_zero_start = Hike.new(@user2, 50.0, 150.0, "Complete Hike Non-zero Start", false).save
    @complete_hike_non_zero_start.create_new_point(58.3, Date.new(2021, 12, 29)).save
    @complete_hike_non_zero_start.create_new_point(71.3, Date.new(2021, 12, 30)).save
    @complete_hike_non_zero_start.create_new_point(80.85, Date.new(2021, 12, 31)).save
    @complete_hike_non_zero_start.create_new_point(89.85, Date.new(2022, 1, 1)).save
    @complete_hike_non_zero_start.create_new_point(104.6, Date.new(2022, 1, 2)).save
    @complete_hike_non_zero_start.create_new_point(124.6, Date.new(2022, 1, 3)).save
    @complete_hike_non_zero_start.create_new_point(124.6, Date.new(2022, 1, 4)).save
    @complete_hike_non_zero_start.create_new_point(135.2, Date.new(2022, 1, 5)).save
    @complete_hike_non_zero_start.create_new_point(135.2, Date.new(2022, 1, 6)).save
    @complete_hike_non_zero_start.create_new_point(150.0, Date.new(2022, 1, 7)).save
    @complete_hike_non_zero_start.mark_complete

    @second_hike_incomplete = Hike.new(@user2, 0.0, 30.0, "Short Hike Incomplete", false).save
    @second_hike_incomplete.create_new_point(4.2, Date.new(2023, 1, 12)).save
    @second_hike_incomplete.create_new_point(9.3, Date.new(2023, 1, 13)).save
  end
end





# olivier = User.new("Olivier", "ochatot").save

# p appalachian.average_mileage_per_day # => 8.56
# p appalachian.mileage_from_finish
