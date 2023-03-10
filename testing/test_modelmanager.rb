require "minitest/autorun"
require "minitest/reporters"
require "pg"
Minitest::Reporters.use!

require_relative "../models"
require_relative "../database_persistence"
require_relative "../model_manager"

# Test basic Model Manager methods with small datasets
class ModelManagerTest < MiniTest::Test
  def setup
    # Database Reset
    database = PG.connect(dbname: "test_thruhike")
    schema_sql = File.open("test_schema.sql", &:read)
    database.exec(schema_sql)

    @manager = ModelManager.new("test_thruhike")

    @user1 = User.new("User One", "user_one_1")
    @manager.insert_new_user(@user1)

    @incomplete_hike_zero_start = Hike.new(@user1, 0.0, 2194.3, "Incomplete Hike Zero Start")
    @manager.insert_new_hike(@incomplete_hike_zero_start)

    point1 = @incomplete_hike_zero_start.create_new_point(8.1, Date.new(2022, 4, 10))
    point2 = @incomplete_hike_zero_start.create_new_point(15.7, Date.new(2022, 4, 11))

    @manager.insert_new_point(point1)
    @manager.insert_new_point(point2)

    @user2 = User.new("User Two", "user_two_2")
    @manager.insert_new_user(@user2)

    @complete_hike_non_zero_start = Hike.new(@user2, 50.0, 150.0, "Complete Hike Non-zero Start")
    @manager.insert_new_hike(@complete_hike_non_zero_start)

    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 58.3, Date.new(2021, 12, 29)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 71.3, Date.new(2021, 12, 30)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 80.85, Date.new(2021, 12, 31)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 89.85, Date.new(2022, 1, 1)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 104.6, Date.new(2022, 1, 2)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 124.6, Date.new(2022, 1, 3)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 124.6, Date.new(2022, 1, 4)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 135.2, Date.new(2022, 1, 5)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 135.2, Date.new(2022, 1, 6)))
    @manager.insert_new_point(Point.new(@complete_hike_non_zero_start, 150.0, Date.new(2022, 1, 7)))

    @second_hike_incomplete = Hike.new(@user2, 0.0, 30.0, "Short Hike Incomplete")
    @manager.insert_new_hike(@second_hike_incomplete)

    @manager.insert_new_point(Point.new(@second_hike_incomplete, 9.3, Date.new(2023, 1, 13)))
    @manager.insert_new_point(Point.new(@second_hike_incomplete, 4.2, Date.new(2023, 1, 12)))

    @goal1 = Goal.new(Date.new(2023, 1, 17), 30.0, "Finish Hike", @second_hike_incomplete)
    @manager.insert_new_goal(@user2, @goal1)
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
    @unsaved_hike = Hike.new(@user1, 0, 100, "test hike")
    point = @unsaved_hike.create_new_point(11.1, Date.today)

    status = @manager.insert_new_point(point)
    assert_equal(false, status.success)
    assert_includes(status.message, "Unable to create new point")
  end
  
  def test_adding_hike_to_nonexistant_user
    @unsaved_user = User.new("Olivier", "ochatot")
    hike = Hike.new(@unsaved_user, 0, 100, "test hike", false)
    
    status = @manager.insert_new_hike(hike)
    assert_includes(status.message, "Unable to create new hike")
  end

  def test_average_mileage_per_day
    status = @manager.average_mileage_per_day(@incomplete_hike_zero_start)
    assert_equal(7.85, status.data)
    
    @manager.insert_new_point(Point.new(@incomplete_hike_zero_start, 26.3, Date.new(2022, 4, 12)))
    @manager.insert_new_point(Point.new(@incomplete_hike_zero_start, 32.4, Date.new(2022, 4, 13)))
    @manager.insert_new_point(Point.new(@incomplete_hike_zero_start, 42.8, Date.new(2022, 4, 14)))
    
    status = @manager.average_mileage_per_day(@incomplete_hike_zero_start)
    assert_equal(8.56, status.data)
  end

  def test_average_mileage_per_day_non_zero_start
    status = @manager.average_mileage_per_day(@complete_hike_non_zero_start)
    assert_equal(10.0, status.data)

    point = @manager.one_point(@complete_hike_non_zero_start, 12).data

    @manager.delete_point(point)
    status = @manager.average_mileage_per_day(@complete_hike_non_zero_start)
    assert_equal(9.47, status.data)
  end

  def test_average_mileage_per_day_no_points
    new_hike = Hike.new(@user1, 0.0, 100.0, "No Points", false)
    @manager.insert_new_hike(new_hike)
    status = @manager.average_mileage_per_day(new_hike)
    assert_equal(0.0, status.data)
  end

  def test_average_mileage_per_day_points_same_as_start_mileage
    new_hike = Hike.new(@user1, 13.0, 100.0, "No Points", false)
    @manager.insert_new_hike(new_hike)
  
    @manager.insert_new_point(Point.new(new_hike, 13.0, Date.today - 1))
    status = @manager.average_mileage_per_day(new_hike)
    assert_equal(0.0, status.data)
    
    @manager.insert_new_point(Point.new(new_hike, 13.0, Date.today))
    status = @manager.average_mileage_per_day(new_hike)
    assert_equal(0.0, status.data)
  end

  def test_mileage_to_finish
    status = @manager.mileage_from_finish(@incomplete_hike_zero_start)
    assert_equal(2178.6, status.data)
    
    @manager.insert_new_point(Point.new(@incomplete_hike_zero_start, 26.3, Date.new(2022, 4, 12)))
    @manager.insert_new_point(Point.new(@incomplete_hike_zero_start, 32.4, Date.new(2022, 4, 13)))
    @manager.insert_new_point(Point.new(@incomplete_hike_zero_start, 42.8, Date.new(2022, 4, 14)))
    
    status = @manager.mileage_from_finish(@incomplete_hike_zero_start)
    assert_equal(2151.5, status.data)
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
    constructed_points = @manager.all_points_from_hike(@incomplete_hike_zero_start).data

    assert_equal(manual_points, constructed_points)
  end

  def test_update_hike_name
    @manager.update_hike_details(@user1, @incomplete_hike_zero_start, "A walk about", @incomplete_hike_zero_start.start_mileage, @incomplete_hike_zero_start.finish_mileage)
    updated_hike = @manager.one_hike(@incomplete_hike_zero_start.id).data
    assert_equal("A walk about", updated_hike.name)
  end

  def test_update_hike_start_mileage
    @manager.update_hike_details(@user1, @incomplete_hike_zero_start, "Incomplete Hike Zero Start", 7.9, @incomplete_hike_zero_start.finish_mileage)
    updated_hike = @manager.one_hike(@incomplete_hike_zero_start.id).data
    assert_equal(7.9, updated_hike.start_mileage)
  end

  def test_update_hike_finish_mileage
    @manager.update_hike_details(@user1, @incomplete_hike_zero_start, "Incomplete Hike Zero Start", @incomplete_hike_zero_start.start_mileage, 3000.0)
    updated_hike = @manager.one_hike(@incomplete_hike_zero_start.id).data
    assert_equal(3000.0, updated_hike.finish_mileage)  
  end

  def test_one_goal
    goal = @manager.one_goal(@second_hike_incomplete, @goal1.id).data
    assert_equal(@goal1, goal)
  end

  def test_one_goal_bad
    goal = @manager.one_goal(@second_hike_incomplete, 32)
    refute(goal.success)
  end

  def test_all_goals_from_hike
    goals = @manager.all_goals_from_hike(@second_hike_incomplete).data
    assert_equal([@goal1], goals)
  end

  def test_delete_goal
    attempt = @manager.delete_goal(@user2, @second_hike_incomplete, @goal1.id)
    assert(attempt.success)

    non_existant_goal = @manager.one_goal(@second_hike_incomplete, @goal1.id)
    refute(non_existant_goal.success)
    assert_equal("Unable to fetch goal", non_existant_goal.message)
  end
end
