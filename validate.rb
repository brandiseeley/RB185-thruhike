module Validate
  def validate_hike_data_types(hike_name, start_mileage, finish_mileage)
    error = false
    unless hike_name && start_mileage && finish_mileage
      session[:message] = "All fields are required"
      redirect "/hikes/new"
    end
    if hike_name.strip.empty?
      session[:message] = "Hike name must be non-empty"
      error = true
    elsif !is_numeric?(start_mileage)
      session[:message] = "Invalid Start Mileage"
      error = true
    elsif !is_numeric?(finish_mileage)
      session[:message] = "Invalid Finish Mileage"
      error = true
    end
    redirect back if error
  end

  def validate_point_data_types(mileage, date, hike_id)
    error = false
    if !is_numeric?(mileage)
      session[:message] = "Invalid Mileage"
      error = true
    elsif date !~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/
      session[:message] = "Invalid Date"
      error = true 
    end
    redirect "/hikes/#{hike_id}" if error
  end

  def validate_goal_data_types(hike_id, date, description, mileage)
    error = false
    if !is_numeric?(mileage)
      session[:message] = "Invalid Mileage"
      error = true
    elsif date !~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/
      session[:message] = "Invalid Date"
      error = true
    elsif description.strip.empty?
      session[:message] = "Invalid Description, must contain characters"
      error = true
    end
    redirect "/hikes/#{hike_id}" if error
  end

  private

  def is_numeric?(string)
    string.to_i.to_s == string || string.to_f.to_s == string
  end
end