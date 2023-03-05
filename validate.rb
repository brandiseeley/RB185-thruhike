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

  # Move to Model Manager
  def validate_hike_to_edit(hike_id, user_id)
    unless user_owns_hike?(user_id, hike_id)
      session[:message] = "Permission denied, unable to edit hike"
      redirect "/hikes"
    end
  end

  def validate_point_data_types(hike_attempt, mileage, date, hike_id)
    error = false
    if !is_numeric?(hike_id) || !hike_attempt.success
      session[:message] = "Error retreiving hike"
      error = true
    elsif !is_numeric?(mileage)
      session[:message] = "Invalid Mileage"
      error = true
    elsif date !~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/
      session[:message] = "Invalid Date"
      error = true 
    end
    redirect "/hikes/#{hike_id}" if error
  end

  # TODO : Move to Model Manager
  def validate_edit_hike_details(user, hike_id, new_hike_name, new_start_mileage, new_finish_mileage)
    all_hikes = @manager.all_hikes_from_user(user.id).data
    error = false
    if !non_negative?(new_start_mileage, new_finish_mileage)
      session[:message] = "Mileages must be non-negative"
      error = true
    elsif !finish_greater_than_start?(new_start_mileage, new_finish_mileage)
      session[:message] = "Finishing mileage must be greater than starting mileage"
      error = true
    elsif all_hikes.any? do |hike|
         new_hike_name == hike.name && hike_id != hike.id
       end
      session[:message] = "You already have a hike titled '#{new_hike_name}'"
      error = true
    elsif mileage_confict_with_existing_points?(hike_id, new_start_mileage, new_finish_mileage)
      session[:message] = "There are existing points within this mileage range. Either change start and finish mileage or delete conficting points and try again"
      error = true
    end
    
    redirect "/hikes/#{hike_id}/edit" if error
  end

  # TODO : Move to Model Manager
  def validate_user_owns_hike_and_point?(user_id, point_id, hike_id)
    user_owns_hike?(user_id, hike_id) && hike_owns_point?(hike_id, point_id)
  end

  private

  # TODO : Move to Model Manager
  def mileage_confict_with_existing_points?(hike_id, start_mileage, finish_mileage)
    all_points = @manager.all_points_from_hike(hike_id).data
    !all_points.all? do |point|
      (start_mileage.to_f..finish_mileage.to_f).cover?(point.mileage.to_f)
    end
  end

  def is_numeric?(string)
    string.to_i.to_s == string || string.to_f.to_s == string
  end


  # TODO : Move to Model Manager
  def user_owns_hike?(user_id, hike_id)
    all_hikes_status = @manager.all_hikes_from_user(user_id)
    if all_hikes_status.success
      all_hikes_status.data.any? { |hike| hike.id == hike_id.to_i }
    else
      false
    end
  end

  # TODO : Move to Model Manager
  def non_negative?(*numbers)
    numbers.all? { |n| n.to_f >= 0 }
  end
  
  # TODO : Move to Model Manager
  def finish_greater_than_start?(start, finish)
    finish.to_f > start.to_f
  end

  # TODO : Move to Model Manager
  def hike_owns_point?(hike_id, point_id)
    points = @manager.all_points_from_hike(hike_id)
    points.data.any? { |point| point.id == point_id.to_i }
  end
end