require_relative "thruhike"
require_relative "database_persistence"
require_relative "model_manager"


Testable.reset_database
Testable.insert_test_data
# brandi = User.new('brandi', 'bs').save
# db = DatabasePersistence.new
# manager = ModelManager.new
# p db.one_user(1)
# p manager.one_user(1)
