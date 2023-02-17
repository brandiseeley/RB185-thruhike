require "minitest/autorun"
require "minitest/reporters"
require "pg"
Minitest::Reporters.use!

require_relative "../thruhike"
require_relative "../database_persistence"

# Test basic ThruHike methods with small datasets
class ThruHikeTest < MiniTest::Test
  def setup
    # Database setup
    @database = PG.connect(dbname: "test_thruhike")
    schema_sql = File.open("test_schema.sql", &:read)
    @database.exec(schema_sql)

    @brandi = User.new("Brandi").save
    @appalachian = Hike.new(@brandi, 0.0, 2194.3, "Appalachian Trail", false).save
    @appalachian.create_new_point(Date.new(2022, 4, 10), 8.1).save
    @appalachian.create_new_point(Date.new(2022, 4, 11), 15.7).save
  end

  def test_adding_point_to_unsaved_hike
    @unsaved_hike = Hike.new(@brandi, 0, 100, "test hike", false)
    point = @unsaved_hike.create_new_point(Date.new, 11.1)
    assert_raises(NoMatchingPKError) { point.save }
  end

  def test_adding_hike_to_nonexistant_user
    @unsaved_user = User.new("Olivier")
    hike = Hike.new(@unsaved_user, 0, 100, "test hike", false)
    assert_raises(NoMatchingPKError) { hike.save }
  end

  def test_average_mileage_per_day
    assert_equal(7.85, @appalachian.average_mileage_per_day)

    @appalachian.create_new_point(Date.new(2022, 4, 12), 26.3).save
    @appalachian.create_new_point(Date.new(2022, 4, 13), 32.4).save
    @appalachian.create_new_point(Date.new(2022, 4, 14), 42.8).save
    assert_equal(8.56, @appalachian.average_mileage_per_day)
  end

  def test_mileage_to_finish
    assert_equal(2178.6, @appalachian.mileage_from_finish)

    @appalachian.create_new_point(Date.new(2022, 4, 12), 26.3).save
    @appalachian.create_new_point(Date.new(2022, 4, 13), 32.4).save
    @appalachian.create_new_point(Date.new(2022, 4, 14), 42.8).save

    assert_equal(2151.5, @appalachian.mileage_from_finish)
  end
end
