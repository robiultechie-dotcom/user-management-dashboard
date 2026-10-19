class UserQueryTool
  # Deterministic API methods for querying accurate database records
  def self.execute(tool_name, arguments = {})
    case tool_name
    when "get_user_statistics"
      {
        total_users: User.count,
        active_users: User.where(status: "active").count,
        blocked_users: User.where(status: "blocked").count
      }

    when "find_user_by_name_or_email"
      q = arguments["query"].to_s.strip.downcase
      user = User.where("LOWER(name) LIKE ? OR LOWER(email) LIKE ?", "%#{q}%", "%#{q}%").first

      if user
        {
          found: true,
          name: user.name,
          email: user.email,
          status: user.status,
          last_seen: user.last_login_at ? user.last_login_at.strftime("%Y-%m-%d %H:%M:%S UTC") : "Never"
        }
      else
        { found: false, query: q }
      end

    when "get_all_users_list"
      User.order(last_login_at: :desc, created_at: :desc).map do |u|
        {
          name: u.name,
          email: u.email,
          status: u.status,
          last_seen: u.last_login_at ? u.last_login_at.strftime("%Y-%m-%d %H:%M") : "Never"
        }
      end

    when "filter_users_by_email_prefix"
      prefixes = Array(arguments["prefixes"]).map { |p| p.to_s.strip.downcase }.reject(&:empty?)
      users = User.all.select do |u|
        prefixes.any? { |p| u.email.downcase.start_with?(p) }
      end
      users.map { |u| { id: u.id, name: u.name, email: u.email, status: u.status } }

    else
      { error: "Unknown tool: #{tool_name}" }
    end
  end
end