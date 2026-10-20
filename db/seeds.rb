users_list = [
  { name: "Robiul Islam", email: "robiul@gmail.com", status: "active",  last_login_at: Time.current },
  { name: "Alex Clare",   email: "alex@gmail.com",   status: "active",  last_login_at: 10.minutes.ago },
  { name: "Jim Morrison", email: "jim@gmail.com",    status: "active",  last_login_at: 2.hours.ago },
  { name: "Nina Simone",  email: "nina@gmail.com",   status: "blocked", last_login_at: 1.day.ago }
]

users_list.each do |data|
  user = User.find_or_initialize_by(email: data[:email])
  if user.new_record?
    user.name = data[:name]
    user.status = data[:status]
    user.last_login_at = data[:last_login_at]
    user.password = "123"
    user.password_confirmation = "123"
    user.save!
  end
end