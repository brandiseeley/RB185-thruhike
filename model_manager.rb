require_relative "thruhike"
require_relative "database_persistence"

# Uses values returned from DatabasePersistence, returns constructed objects
class ModelManager
  def initialize
    @database = DatabasePersistence.new
  end

  # returns array of User objects
  def all_users
    @database.all_users.map do |user_data|
      construct_user(user_data)
    end
  end

  def one_user(user_name)
    user = @database.one_user(user_name).first
    construct_user(user)
  end

  private

  # ["1", "Brandi", "brandi_s"]
  def construct_user(row)
    User.new(row["name"], row["user_name"], row["id"].to_i)
  end
end
