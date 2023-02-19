require_relative "thruhike"
require_relative "database_persistence"
require_relative "model_manager"


# Testable.reset_database
# Testable.insert_test_data

# @manager = ModelManager.new
# p User.new('brandi', 'bs').save

# @database = DatabasePersistence.new
# @manager = ModelManager.new

# @user1 = User.new("User One", "user_one_1").save
# @incomplete_hike_zero_start = Hike.new(@user1, 0.0, 2194.3, "Incomplete Hike Zero Start", false).save
# @incomplete_hike_zero_start.create_new_point(8.1, Date.new(2022, 4, 10)).save
# @incomplete_hike_zero_start.create_new_point(15.7, Date.new(2022, 4, 11)).save
# p @user1
# p @incomplete_hike_zero_start
