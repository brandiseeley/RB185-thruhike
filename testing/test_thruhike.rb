require "minitest/autorun"
require "minitest/reporters"
require "pg"
Minitest::Reporters.use!

require_relative "../thruhike"
require_relative "../database_persistence"

class ThruHikeTest < MiniTest::Test

  def setup
    # Database setup
    @database = PG.connect(dbname: "test_thruhike")
    schema_sql = File.open("test_schema.sql", "rb") { |file| file.read }
    @database.exec(schema_sql)

    @brandi = User.new("Brandi").save
    @appalachian = Hike.new(@brandi, 0.0, 2193.0, "Appalachian Trail", false).save
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
end
