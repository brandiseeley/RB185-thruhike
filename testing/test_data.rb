Testable.reset_database

brandi = User.new("Brandi", "brandi_s").save
appalachian = Hike.new(brandi, 0.0, 2194.3, "Appalachian Trail", false).save
appalachian.create_new_point(Date.new(2022, 4, 10), 8.1).save
appalachian.create_new_point(Date.new(2022, 4, 11), 15.7).save
appalachian.create_new_point(Date.new(2022, 4, 12), 26.3).save
appalachian.create_new_point(Date.new(2022, 4, 13), 32.4).save
appalachian.create_new_point(Date.new(2022, 4, 14), 42.8).save

olivier = User.new("Olivier", "ochatot").save

p appalachian.average_mileage_per_day # => 8.56
p appalachian.mileage_from_finish
