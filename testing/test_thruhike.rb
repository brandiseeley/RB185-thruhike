require "minitest/autorun"
require "minitest/reporters"
require "pg"
Minitest::Reporters.use!

require_relative "../thruhike"
require_relative "../database_persistence"
require_relative "../model_manager"

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

    @manager = ModelManager.new

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
    @second_hike_incomplete.create_new_point(4.2, Date.new(2023, 1, 12))
    @second_hike_incomplete.create_new_point(9.3, Date.new(2023, 1, 13))
  end

  def teardown
    sql = <<-SQL
          SELECT pg_terminate_backend(pg_stat_activity.pid)
          FROM pg_stat_activity
          WHERE pg_stat_activity.datname = 'test_thruhike'
          AND pid <> pg_backend_pid();
    SQL

    database = PG.connect(dbname: "test_thruhike")
    database.exec(sql)

  end

  def test_adding_point_to_unsaved_hike
    @unsaved_hike = Hike.new(@user1, 0, 100, "test hike", false)
    point = @unsaved_hike.create_new_point(11.1, Date.new)
    assert_raises(NoMatchingPKError) { point.save }
  end

  def test_adding_hike_to_nonexistant_user
    @unsaved_user = User.new("Olivier", "ochatot")
    hike = Hike.new(@unsaved_user, 0, 100, "test hike", false)
    assert_raises(NoMatchingPKError) { hike.save }
  end

  def test_average_mileage_per_day
    assert_equal(7.85, @incomplete_hike_zero_start.average_mileage_per_day.data)

    @incomplete_hike_zero_start.create_new_point(26.3, Date.new(2022, 4, 12)).save
    @incomplete_hike_zero_start.create_new_point(32.4, Date.new(2022, 4, 13)).save
    @incomplete_hike_zero_start.create_new_point(42.8, Date.new(2022, 4, 14)).save
    assert_equal(8.56, @incomplete_hike_zero_start.average_mileage_per_day.data)
  end

  def test_mileage_to_finish
    assert_equal(2178.6, @incomplete_hike_zero_start.mileage_from_finish.data)

    @incomplete_hike_zero_start.create_new_point(26.3, Date.new(2022, 4, 12)).save
    @incomplete_hike_zero_start.create_new_point(32.4, Date.new(2022, 4, 13)).save
    @incomplete_hike_zero_start.create_new_point(42.8, Date.new(2022, 4, 14)).save

    assert_equal(2151.5, @incomplete_hike_zero_start.mileage_from_finish.data)
  end

  # Test Model Manager
  def test_all_users
    constructed_users = @manager.all_users.data
    manual_users = [@user1, @user2].sort
    assert_equal(manual_users, constructed_users)
  end

  def test_one_user
    constructed_first_user = @manager.one_user(1).data
    assert_equal(@user1, constructed_first_user)
  end

  def test_all_hikes_from_user
    constructed_hike = @manager.all_hikes_from_user(1).data
    manual_hike = [@incomplete_hike_zero_start]
    assert_equal(manual_hike, constructed_hike)

    constructed_hikes = @manager.all_hikes_from_user(2).data
    manual_hikes = [@complete_hike_non_zero_start, @second_hike_incomplete].sort
    assert_equal(manual_hikes, constructed_hikes)
  end

  def test_one_hike
    assert_equal(@incomplete_hike_zero_start, @manager.one_hike(1).data)
    assert_equal(@second_hike_incomplete, @manager.one_hike(3).data)
    assert_equal(@complete_hike_non_zero_start, @manager.one_hike(2).data)
  end

  def test_all_points_from_hike
    manual_points = [
          Point.new(@incomplete_hike_zero_start, 8.1, Date.new(2022, 4, 10)),
          Point.new(@incomplete_hike_zero_start, 15.7, Date.new(2022, 4, 11))
    ].sort
    constructed_points = @manager.all_points_from_hike(1).data

    assert_equal(manual_points, constructed_points)
  end

  def test_mark_complete
    assert_equal(false, @incomplete_hike_zero_start.completed)
    @incomplete_hike_zero_start.mark_complete
    assert_equal(true, @incomplete_hike_zero_start.completed)
  end
end
