require 'json'

# ONLY with users from users.json
file_path = Rails.root.join('db', 'users.json')

if File.exist?(file_path)
  users_data = JSON.parse(File.read(file_path))
  
  # Remove any non-file custom users if count or emails don't match
  expected_emails = users_data.map { |u| u["email"].strip.downcase }
  User.where.not("LOWER(email) IN (?)", expected_emails).destroy_all

  users_data.each do |data|
    user = User.find_or_initialize_by(email: data["email"].strip.downcase)
    user.name = data["full_name"]
    user.job_position = data["job_position"]
    user.status = data["status"]
    user.last_login_at = Time.parse(data["last_seen"]) rescue Time.current
    user.password = "123"
    user.password_confirmation = "123"
    user.save!
  end

  puts "Successfully seeded #{User.count} users from users.json!"
else
  puts "Error: db/users.json file not found!"
end