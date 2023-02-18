require "minitest/autorun"
require "minitest/reporters"
require "pg"
require "pry"
Minitest::Reporters.use!

require_relative "../thruhike"
require_relative "../database_persistence"

# Have to override initialize for DatabasePersistence so we connect to test database
class DatabasePersistence
  def initialize
    @database = PG.connect(dbname: "test_thruhike")
  end
end

# Test basic ThruHike methods with small datasets
class ThruHikeTest < MiniTest::Test
  def setup
    # Database Reset
    database = PG.connect(dbname: "test_thruhike")
    schema_sql = File.open("test_schema.sql", &:read)
    database.exec(schema_sql)

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
    @second_hike_incomplete.create_new_point(Date.new(2023, 1, 12), 4.2)
    @second_hike_incomplete.create_new_point(Date.new(2023, 1, 13), 9.3)
  end

  def test_adding_point_to_unsaved_hike
    @unsaved_hike = Hike.new(@user1, 0, 100, "test hike", false)
    point = @unsaved_hike.create_new_point(Date.new, 11.1)
    assert_raises(NoMatchingPKError) { point.save }
  end

  def test_adding_hike_to_nonexistant_user
    @unsaved_user = User.new("Olivier", "ochatot")
    hike = Hike.new(@unsaved_user, 0, 100, "test hike", false)
    assert_raises(NoMatchingPKError) { hike.save }
  end

  def test_average_mileage_per_day
    assert_equal(7.85, @incomplete_hike_zero_start.average_mileage_per_day)

    @incomplete_hike_zero_start.create_new_point(Date.new(2022, 4, 12), 26.3).save
    @incomplete_hike_zero_start.create_new_point(Date.new(2022, 4, 13), 32.4).save
    @incomplete_hike_zero_start.create_new_point(Date.new(2022, 4, 14), 42.8).save
    assert_equal(8.56, @incomplete_hike_zero_start.average_mileage_per_day)
  end

  def test_mileage_to_finish
    assert_equal(2178.6, @incomplete_hike_zero_start.mileage_from_finish)

    @incomplete_hike_zero_start.create_new_point(Date.new(2022, 4, 12), 26.3).save
    @incomplete_hike_zero_start.create_new_point(Date.new(2022, 4, 13), 32.4).save
    @incomplete_hike_zero_start.create_new_point(Date.new(2022, 4, 14), 42.8).save

    assert_equal(2151.5, @incomplete_hike_zero_start.mileage_from_finish)
  end
end
