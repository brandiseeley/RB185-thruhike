ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
require "pg"
Minitest::Reporters.use!

require_relative "../thruhike_app"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def log_in_user_2
    { "rack.session" => { user_id: "2" } }
  end

  def new_hike_params
    { "name" => "Long Walk",
      "start_mileage" => "0",
      "finish_mileage" => "100" }
  end

  def setup
    # Database Reset
    database = PG.connect(dbname: "test_thruhike")
    schema_sql = File.open("test_schema.sql", &:read)
    database.exec(schema_sql)

    @manager = ModelManager.new("test_thruhike")

    @user1 = User.new("User One", "user_one_1")
    @manager.insert_new_user(@user1)

    @incomplete_hike_zero_start = Hike.new(@user1, 0.0, 2194.3, "Incomplete Hike Zero Start", false)
    @manager.insert_new_hike(@incomplete_hike_zero_start)

    point1 = @incomplete_hike_zero_start.create_new_point(8.1, Date.new(2022, 4, 10))
    point2 = @incomplete_hike_zero_start.create_new_point(15.7, Date.new(2022, 4, 11))

    @manager.insert_new_point(point1)
    @manager.insert_new_point(point2)

    @user2 = User.new("User Two", "user_two_2")
    @manager.insert_new_user(@user2)

    @complete_hike_non_zero_start = Hike.new(@user2, 50.0, 150.0, "Complete Hike Non-zero Start", false)
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

    @complete_hike_non_zero_start.mark_complete
    @manager.mark_hike_complete(@complete_hike_non_zero_start)

    @second_hike_incomplete = Hike.new(@user2, 0.0, 30.0, "Short Hike Incomplete", false)
    @manager.insert_new_hike(@second_hike_incomplete)

    @manager.insert_new_point(Point.new(@second_hike_incomplete, 9.3, Date.new(2023, 1, 13)))
    @manager.insert_new_point(Point.new(@second_hike_incomplete, 4.2, Date.new(2023, 1, 12)))
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

  def test_root
    get "/"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "user_one_1")
    assert_includes(last_response.body, "user_two_2")
  end

  # Not Logged In tests
  def test_get_hikes_not_logged_in
    get "/hikes"
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("You must be logged in to do that", session[:message])
    follow_redirect!
    assert_equal(200, last_response.status)
  end

  def test_post_hikes_not_logged_in
    post "/hikes/new"
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("You must be logged in to do that", session[:message])
    follow_redirect!
    assert_equal(200, last_response.status)
  end

  def test_new_hike_not_logged_in
    get "/hikes/new"
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("You must be logged in to do that", session[:message])
    follow_redirect!
    assert_equal(200, last_response.status)
  end

  # Signed in User 2
  def test_get_hikes_user_2
    get "/hikes", {}, log_in_user_2
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "Short Hike Incomplete")
    assert_includes(last_response.body, "Complete Hike Non-zero Start")
  end

  def test_get_hike_2_user_2
    get "/hikes/2", {}, log_in_user_2
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "2022-01-07")
    assert_includes(last_response.body, "150.0")
    assert_includes(last_response.body, "2022-01-06")
    assert_includes(last_response.body, "135.2")
    assert_includes(last_response.body, "2021-12-29")
    assert_includes(last_response.body, "58.3")
  end

  # Create Hike Tests
  def test_create_hike_page
    get "/hikes/new", {}, log_in_user_2
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "Enter the Details for Your New Hike")
    assert_includes(last_response.body, "<form action=\"/hikes/new\" method=\"POST\">")
  end
  
  def test_create_new_hike_user_2
    post "/hikes/new", new_hike_params, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Hike successfully created", session[:message])

    follow_redirect!
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Long Walk")
  end
  
  def test_create_hike_no_name
    post "/hikes/new", { "start_mileage" => "0", "finish_mileage" => "100" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("All fields are required", session[:message])
  
    follow_redirect!
    assert_equal(200, last_response.status)
  end
  
  def test_create_hike_whitespace_name
    post "/hikes/new", { "name" => "   ", "start_mileage" => "0", "finish_mileage" => "100" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Hike name must be non-empty", session[:message])
  
    follow_redirect!
    assert_equal(200, last_response.status)
  end
  
  def test_create_hike_nonnumeric_start_mileage
    post "/hikes/new", { "name" => "Long Walk", "start_mileage" => "string", "finish_mileage" => "100" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Invalid Start Mileage", session[:message])
  
    follow_redirect!
    assert_equal(200, last_response.status)
  end
  
  def test_create_hike_negative_start_mileage
    post "/hikes/new", { "name" => "Long Walk", "start_mileage" => "-42", "finish_mileage" => "100" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Mileages must be non-negative", session[:message])
    
    follow_redirect!
    assert_equal(200, last_response.status)
  end
  
  def test_create_hike_invalid_finish_mileage
    post "/hikes/new", { "name" => "Long Walk", "start_mileage" => "23", "finish_mileage" => "string" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Invalid Finish Mileage", session[:message])
    
    follow_redirect!
    assert_equal(200, last_response.status)
  end
  
  def test_create_hike_negative_finish_mileage
    post "/hikes/new", { "name" => "Long Walk", "start_mileage" => "2", "finish_mileage" => "-100" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Mileages must be non-negative", session[:message])
    
    follow_redirect!
    assert_equal(200, last_response.status)
  end
  
  def test_create_hike_invalid_mileage_range
    post "/hikes/new", { "name" => "Long Walk", "start_mileage" => "100", "finish_mileage" => "10" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Finishing mileage must be greater than starting mileage", session[:message])
    
    follow_redirect!
    assert_equal(200, last_response.status)
  end
  
  def test_create_hike_duplicate_name
    post "/hikes/new", { "name" => "Short Hike Incomplete", "start_mileage" => "10", "finish_mileage" => "100" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("You already have a hike titled 'Short Hike Incomplete'", session[:message])
    
    follow_redirect!
    assert_equal(200, last_response.status)
    
  end

  # Delete Hike Tests
  def test_delete_hike_user_2
    post "/hikes/delete", { "hike_id" => "2" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Hike successfully deleted", session[:message])

    follow_redirect!
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, "Complete Hike Non-zero Start")
  end

  def test_deleting_hike_of_other_user_user_2
    post "/hikes/delete", { "hike_id" => "1" }, log_in_user_2

    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Permission denied, unable to edit hike", session[:message])
  end

  def test_deleting_non_existant_hike_user_2
    post "/hikes/delete", { "hike_id" => "42" }, log_in_user_2

    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Permission denied, unable to edit hike", session[:message])
  end

  def test_deleting_hike_not_logged_in
    post "/hikes/delete", { "hike_id" => "2" }

    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("You must be logged in to do that", session[:message])
  end

  # Creating Point Tests
  def test_create_point_user_2
    post "/hikes/3", { "date" => "2023-01-14", "mileage" => "13.3", "hike_id" => "3" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Point successfully created", session[:message])
    
    follow_redirect!
    assert_includes(last_response.body, "4.43")
  end
  
  def test_create_point_with_existing_date
    post "/hikes/3", { "date" => "2023-01-13", "mileage" => "13.3", "hike_id" => "3" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Each day may only have one point", session[:message])

    follow_redirect!
    refute_includes(last_response.body, "13.3")
  end
  
  def test_create_point_no_mileage
    post "/hikes/3", { "date" => "2023-01-14", "hike_id" => "3" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Invalid Mileage", session[:message])
    
    follow_redirect!
    refute_includes(last_response.body, "13.3")
  end
  
  def test_creating_point_no_date
    post "/hikes/3", { "mileage" => "13.3", "hike_id" => "3" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Invalid Date", session[:message])
    
    follow_redirect!
    refute_includes(last_response.body, "13.3")
  end
  
  def test_create_point_out_of_range
    post "/hikes/3", { "date" => "2023-01-14", "mileage" => "999.3", "hike_id" => "3" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Mileage must be ascending or equal from one day to a following day", session[:message])
    
    follow_redirect!
    refute_includes(last_response.body, "13.3")
  end
  
  def test_create_point_out_of_date_range
    post "/hikes/3", { "date" => "2023-01-15", "mileage" => "22.0", "hike_id" => "3" }, log_in_user_2
    post "/hikes/3", { "date" => "2023-01-14", "mileage" => "28.0", "hike_id" => "3" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Mileage must be ascending or equal from one day to a following day", session[:message])
    
    follow_redirect!
    assert_includes(last_response.body, "22.0")
    refute_includes(last_response.body, "28.0")
  end
  
  def test_create_point_out_of_date_range_2
    post "/hikes/3", { "date" => "2023-01-11", "mileage" => "4.9", "hike_id" => "3" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Mileage must be ascending or equal from one day to a following day", session[:message])
    
    follow_redirect!
    refute_includes(last_response.body, "4.9")
  end
  
  def test_create_point_zero_day
    post "/hikes/3", { "date" => "2023-01-14", "mileage" => "9.3", "hike_id" => "3" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Point successfully created", session[:message])
    
    follow_redirect!
    assert_includes(last_response.body, "31.0%")
  end

  # Test deleting points
  def test_delete_point_user_2
    post "/hikes/3/delete", { "point_id" => "13" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Point successfully deleted", session[:message])
    
    follow_redirect!
    refute_includes(last_response.body, "2023-01-13")
    refute(@manager.one_point("13").success)
  end
  
  def test_delete_point_other_users_hike
    post "/hikes/1/delete", { "point_id" => "13" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Permission to edit this hike denied", session[:message])

    assert(@manager.one_point("13").success)
  end
  
  def test_delete_non_existent_point
    post "/hikes/3/delete", { "point_id" => "42" }, log_in_user_2
    assert_equal(302, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal("Permission to edit this hike denied", session[:message])
  end
  
  # Test statistics
  def test_miles_hiked
    get "/hikes/3", {}, log_in_user_2
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "5.1")
    assert_includes(last_response.body, "4.2")
  end
  
  def test_percent_complete
    get "/hikes/3", {}, log_in_user_2
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "31.0%")
    
    post "/hikes"
  end
end