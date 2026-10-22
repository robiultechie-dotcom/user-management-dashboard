# frozen_string_literal: true

# Database + UI-command tools exposed to the LLM via function calling.
# All filtering happens in SQL (no Ruby-side loading of the users table).
class UserQueryTool
  LIMIT = 10
  FILTER_KEYS = %w[query status job_position email_starts_with name_starts_with].freeze

  FILTER_PROPS = {
    query:             { type: "string", description: "Text contained in the user's name or email." },
    status:            { type: "string", enum: %w[active blocked] },
    job_position:      { type: "string", description: "Text contained in the job position." },
    email_starts_with: { type: "array", items: { type: "string" }, description: "Email prefixes (OR)." },
    name_starts_with:  { type: "array", items: { type: "string" }, description: "Name prefixes (OR)." }
  }.freeze

  DECLARATIONS = [
    { name: "get_user_statistics",
      description: "Total, active and blocked user counts." },
    { name: "search_users",
      description: "Count and list (max #{LIMIT}) users matching ALL given filters. No filters = most recent users.",
      parameters: { type: "object", properties: FILTER_PROPS } },
    { name: "select_users",
      description: "Select (check) matching rows in the UI table. Use all=true to select every user.",
      parameters: { type: "object", properties: FILTER_PROPS.merge(all: { type: "boolean" }) } },
    { name: "deselect_all",
      description: "Clear every selection in the UI table." }
  ].freeze

  class << self
    def execute(tool_name, arguments = {})
      args = (arguments || {}).to_h.stringify_keys

      case tool_name.to_s
      when "get_user_statistics" then statistics
      when "search_users"        then search(args)
      when "select_users"        then select(args)
      when "deselect_all"        then { cleared: true, command: { action: "deselect_all" } }
      else { error: "Unknown tool: #{tool_name}" }
      end
    end

    private

    def statistics
      by_status = User.group(:status).count
      { total_users: by_status.values.sum,
        active_users: by_status["active"].to_i,
        blocked_users: by_status["blocked"].to_i }
    end

    def search(args)
      rel = filtered(args)
      { count: rel.count,
        users: rel.order(last_login_at: :desc, created_at: :desc).limit(LIMIT).map { |u| present(u) } }
    end

    def select(args)
      return { error: "Provide at least one filter or all=true." } unless args["all"] || (args.keys & FILTER_KEYS).any?

      ids = (args["all"] ? User.all : filtered(args)).pluck(:id)
      { selected_count: ids.size, command: { action: "select_users", user_ids: ids } }
    end

    def filtered(args)
      rel = User.all
      rel = rel.where(status: args["status"]) if args["status"].present?
      rel = rel.where("LOWER(name) LIKE :q OR LOWER(email) LIKE :q", q: like(args["query"])) if args["query"].present?
      rel = rel.where("LOWER(job_position) LIKE ?", like(args["job_position"])) if args["job_position"].present?

      { "email" => args["email_starts_with"], "name" => args["name_starts_with"] }.each do |column, prefixes|
        list = Array(prefixes).map { |p| p.to_s.strip.downcase }.reject(&:empty?)
        next if list.empty?

        rel = rel.where(list.map { "LOWER(#{column}) LIKE ?" }.join(" OR "),
                        *list.map { |p| "#{User.sanitize_sql_like(p)}%" })
      end
      rel
    end

    def like(text)
      "%#{User.sanitize_sql_like(text.to_s.strip.downcase)}%"
    end

    def present(user)
      { name: user.name, email: user.email, job_position: user.job_position.presence || "N/A",
        status: user.status, last_seen: user.last_login_at&.utc&.iso8601 || "never" }
    end
  end
end