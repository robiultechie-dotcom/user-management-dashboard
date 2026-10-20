# Clear existing data and seed exactly 4 clean users with simple emails
User.destroy_all

users_list = [
  { name: "Robiul Islam", email: "robiul@gmail.com", status: "active",  last_login_at: Time.current },
  { name: "Alex Clare",   email: "alex@gmail.com",   status: "active",  last_login_at: 10.minutes.ago },
  { name: "Jim Morrison", email: "jim@gmail.com",    status: "active",  last_login_at: 2.hours.ago },
  { name: "Nina Simone",  email: "nina@gmail.com",   status: "blocked", last_login_at: 1.day.ago }
]

users_list.each do |data|
  User.create!(
    name: data[:name],
    email: data[:email],
    status: data[:status],
    last_login_at: data[:last_login_at],
    password: "123",
    password_confirmation: "123"
  )
end