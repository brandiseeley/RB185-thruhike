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
    redirect "/hikes/new" if error
  end

  def validate_hike_to_delete(hike_id, user_id)
    unless user_owns_hike?(user_id, hike_id)
      session[:message] = "Permission denied, unable to delete hike"
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

  def validate_hike_details(hike_name, start_mileage, finish_mileage, user)
    error = false
    if start_mileage < 0 || finish_mileage < 0
      session[:message] = "Mileages must be non-negative"
      error = true
    elsif finish_mileage - start_mileage <= 0
      session[:message] = "Finishing mileage must be greater than starting mileage"
      error = true
    elsif duplicate_name?(hike_name, user)
      session[:message] = "You already have a hike titled '#{hike_name}'"
      error = true
    end
    redirect "/hikes/new" if error
  end

  def validate_point_details(hike, mileage, date, hike_id, user)
    points = @manager.all_points_from_hike(hike_id).data
    error = false
    if points.any? { |p| to_date(date) === p.date }
      session[:message] = "Each day may only have one point"
      error = true
    elsif !validate_linear_mileage?(date, mileage, points, hike)
      session[:message] = "Mileage must be ascending or equal from one day to a following day"
      error = true
    elsif !user_owns_hike?(user.id, hike_id)
      session[:message] = "Permission to edit this hike denied"
      error = true
    end
    redirect "/hikes/#{hike_id}" if error
  end

  def validate_user_owns_hike_and_point?(user_id, point_id, hike_id)
    user_owns_hike?(user_id, hike_id) && hike_owns_point?(hike_id, point_id)
  end

  
  private

  def is_numeric?(string)
    string.to_i.to_s == string || string.to_f.to_s == string
  end


  def duplicate_name?(hike_name, user)
    all_hikes = @manager.all_hikes_from_user(user.id).data
    all_hikes.any? { |hike| hike.name == hike_name }
  end
  
  
  def validate_linear_mileage?(date, mileage, points, hike)
    date = to_date(date)
  
    mileage_before = hike.start_mileage
    
    points.reverse_each do |point|
      if point.date <= date
        mileage_before = point.mileage
      else
        break
      end
    end
    
    mileage_after = hike.finish_mileage
  
    points.each do |point|
      if point.date > date
        mileage_after = point.mileage
      else
        break
      end
    end
  
    (mileage_before..mileage_after).cover?(mileage)
  end
    
  def to_date(string)
    Date.parse(string)
  end

  def user_owns_hike?(user_id, hike_id)
    all_hikes_status = @manager.all_hikes_from_user(user_id)
    if all_hikes_status.success
      all_hikes_status.data.any? { |hike| hike.id == hike_id.to_i }
    else
      false
    end
  end
  
  def hike_owns_point?(hike_id, point_id)
    points = @manager.all_points_from_hike(hike_id)
    points.data.any? { |point| point.id == point_id.to_i }
  end
end