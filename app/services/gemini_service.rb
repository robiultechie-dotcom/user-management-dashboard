require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'cgi'

class GeminiService
  GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent".freeze
  STOP_WORDS = %w[or and the letter letters email emails user users with in table].freeze

  KNOWLEDGE_BASE = {
    /\b(js|javascript)\b/ => "<strong>JavaScript (JS)</strong> is a high-level, dynamic programming language and a core technology of the World Wide Web alongside HTML and CSS. It enables interactive web pages and runs on servers via Node.js.",
    /typescript|\bts\b/   => "<strong>TypeScript</strong> is a strongly typed programming language developed by Microsoft that builds on JavaScript by adding static type definitions.",
    /c\+\+|cpp/           => "<strong>C++</strong> is a high-performance compiled programming language created by Bjarne Stroustrup, widely used in game engines, systems software, and performance-critical applications.",
    /c#|csharp/           => "<strong>C# (C-Sharp)</strong> is a modern, object-oriented programming language developed by Microsoft as part of the .NET ecosystem.",
    /python/              => "<strong>Python</strong> is a popular high-level, interpreted programming language known for its clean readability and massive ecosystem in AI, machine learning, data science, and web development.",
    /ruby on rails|\brails\b/ => "<strong>Ruby on Rails</strong> is a productive full-stack web application framework written in Ruby, built on the MVC pattern and the principles of Convention over Configuration and DRY.",
    /ruby/                => "<strong>Ruby</strong> is a dynamic, open-source, object-oriented programming language created by Yukihiro 'Matz' Matsumoto, designed for programmer happiness and simplicity.",
    /\bjava\b/            => "<strong>Java</strong> is a widely used, class-based, object-oriented programming language designed around the 'Write Once, Run Anywhere' (WORA) principle via the JVM.",
    /\b(usa|united states|america)\b/ => "The <strong>United States of America (USA)</strong> is a country primarily located in North America consisting of 50 states and a federal district (Washington, D.C.).",
    /bangladesh|dhaka/    => "<strong>Bangladesh</strong> is a vibrant South Asian country on the Bay of Bengal, known for its rich rivers, lush greenery, and its capital city, Dhaka.",
    /facebook|meta/       => "<strong>Facebook</strong> is the world's largest online social networking service, founded by Mark Zuckerberg in 2004 and owned by Meta Platforms."
  }.freeze

  # Main entry point for handling user queries and UI commands
  def self.ask(question, _current_user = nil)
    q = question.to_s.strip
    return { answer: "Please enter a question or command." } if q.blank?

    if (greeting = handle_instant_greetings(q))
      return { answer: greeting }
    end

    if (table_cmd = process_table_command(q))
      return table_cmd
    end

    return { answer: answer_database_query(q) } if is_database_query?(q)

    if (fast_knowledge = instant_knowledge_base(q))
      return { answer: fast_knowledge }
    end

    if (live_answer = fetch_fast_live_knowledge(q))
      return { answer: live_answer }
    end

    { answer: "I am your Data Assistant. You can ask me about your application users, filter table rows, or ask general questions!" }
  rescue StandardError => e
    Rails.logger.error("GeminiService Error: #{e.message}")
    { answer: "I'm ready to help with your user data or questions. What would you like to know?" }
  end

  private

  # Instant in-memory responses for common greetings
  def self.handle_instant_greetings(q)
    case q.downcase.strip
    when /\A(hi|hello|hey|heya|howdy|good morning|good afternoon|good evening|greetings|assalamu alaikum|salam)[\s!.?]*\z/i
      "Hello! How can I help you today?"
    when /\A(how are you|how's it going|whats up|what's up|how do you do)[\s!.?]*\z/i
      "I'm doing great, thank you! Ready to help with your users or answer any questions."
    when /\A(thanks|thank you|thx|ty|ok|okay|great|nice|awesome|cool)[\s!.?]*\z/i
      "You're very welcome! Let me know if you need anything else."
    when /\A(who are you|what are you|what can you do|help)[\s!.?]*\z/i
      "I am your AI Data Assistant. I can query live user statistics, check user statuses, select rows in the table, and answer general knowledge or programming questions!"
    end
  end

  # Part 3: UI table selection commands
  def self.process_table_command(question)
    q = question.downcase.strip

    if q.match?(/\b(deselect|unselect|uncheck|clear selection|select none)\b/)
      return { answer: "Cleared all selections in the table.", command: { action: "deselect_all" } }
    end

    if q.match?(/\b(select all|check all|select everyone)\b/)
      ids = User.pluck(:id)
      return { answer: "Selected all <strong>#{ids.size}</strong> users in the table.", command: { action: "select_users", user_ids: ids } }
    end

    if q.match?(/\b(select|check|highlight)\b/) && q.match?(/\b(start|begin|starts|begins|starting|beginning)\b/)
      target_field = q.include?("name") ? :name : :email
      prefixes = extract_prefixes(q)

      if prefixes.any?
        matched = match_users_by_prefix(target_field, prefixes)
        ids = matched.map(&:first)
        names = matched.map { |_, n, e| "#{n} (#{e})" }.join(", ")
        p_disp = prefixes.map { |p| "'#{p}'" }.join(" or ")

        return {
          answer: ids.any? ? "Selected <strong>#{ids.size}</strong> user(s) with #{target_field} starting with #{p_disp}: #{names}." : "No users found with #{target_field} starting with #{p_disp}.",
          command: { action: "select_users", user_ids: ids }
        }
      end
    end

    if q.match?(/\b(select|check)\b/) && (q.include?("blocked") || q.include?("active"))
      target = q.include?("blocked") ? "blocked" : "active"
      ids = User.where(status: target).pluck(:id)
      return {
        answer: ids.any? ? "Selected all <strong>#{ids.size}</strong> #{target} users in the table." : "There are no #{target} users to select.",
        command: { action: "select_users", user_ids: ids }
      }
    end

    if q.match?(/\b(select|check|highlight)\b/)
      matched = User.pluck(:id, :name, :email).select do |_, n, e|
        n_str, e_str = n.to_s.downcase, e.to_s.downcase
        parts = n_str.split.select { |p| p.length >= 3 }
        q.include?(n_str) || q.include?(e_str) || parts.any? { |p| q.match?(/\b#{Regexp.escape(p)}\b/) }
      end

      if matched.any?
        return {
          answer: "Selected #{matched.map { |_, n, e| "<strong>#{n}</strong> (#{e})" }.join(', ')} in the table.",
          command: { action: "select_users", user_ids: matched.map(&:first) }
        }
      end
    end

    nil
  end

  # Part 2: Deterministic database queries
  def self.answer_database_query(question)
    q = question.downcase.strip

    if q.match?(/\b(start|begin|starts|begins|starting|beginning)\b/) && q.match?(/\b(email|emails|name|names|user|users)\b/)
      target_field = q.include?("name") ? :name : :email
      prefixes = extract_prefixes(q)

      if prefixes.any?
        matched = match_users_by_prefix(target_field, prefixes)
        p_disp = prefixes.map { |p| "'#{p}'" }.join(" or ")

        if q.match?(/\b(how many|count|number)\b/)
          return "There #{matched.size == 1 ? 'is' : 'are'} <strong>#{matched.size}</strong> user(s) with #{target_field} starting with #{p_disp}."
        end
        return matched.any? ? "User(s) with #{target_field} starting with #{p_disp}: " + matched.map { |_, n, e| "<strong>#{n}</strong> (<code>#{e}</code>)" }.join(", ") : "No users found with #{target_field} starting with #{p_disp}."
      end
    end

    matched = User.pluck(:name, :email).find { |n, e| q.include?(n.to_s.downcase) || q.include?(e.to_s.downcase) }
    if matched
      info = UserQueryTool.execute("find_user_by_name_or_email", { "query" => matched.last })
      return "#{info[:name]}'s email is <code>#{info[:email]}</code>." if q.include?("email")
      return "#{info[:name]} was last seen on <strong>#{info[:last_seen]}</strong>." if q.match?(/last|seen|login|when/)
      return (info[:status].to_s.downcase == "blocked" ? "Yes, <strong>#{info[:name]}</strong> is currently Blocked." : "No, <strong>#{info[:name]}</strong> is Active.") if q.include?("block")
      return "User <strong>#{info[:name]}</strong> (#{info[:email]}) is <strong>#{info[:status].capitalize}</strong>, last seen: #{info[:last_seen]}."
    end

    if q.include?("block") && q.match?(/\b(who|which|list)\b/)
      blocked = User.where(status: "blocked")
      return blocked.any? ? "Blocked user(s): " + blocked.map { |u| "<strong>#{u.name}</strong> (<code>#{u.email}</code>)" }.join(", ") : "There are currently <strong>0</strong> blocked users in the system."
    end

    if q.include?("active") && q.match?(/\b(who|which|list)\b/)
      active = User.where(status: "active")
      return active.any? ? "Active user(s): " + active.map { |u| "<strong>#{u.name}</strong> (<code>#{u.email}</code>)" }.join(", ") : "There are currently no active users."
    end

    if q.match?(/how many|count|total|number of|stats/)
      stats = UserQueryTool.execute("get_user_statistics")
      return "There #{stats[:blocked_users] == 1 ? 'is' : 'are'} <strong>#{stats[:blocked_users]}</strong> blocked user(s)." if q.include?("block") && !q.include?("active")
      return "There #{stats[:active_users] == 1 ? 'is' : 'are'} <strong>#{stats[:active_users]}</strong> active user(s)." if q.include?("active") && !q.include?("block")
      return "Total users: <strong>#{stats[:total_users]}</strong> (Active: #{stats[:active_users]}, Blocked: #{stats[:blocked_users]})."
    end

    if q.match?(/list|show|all users|who are the users/)
      users = UserQueryTool.execute("get_all_users_list")
      return "No users found in database." if users.empty?
      return "Current registered users:<br>" + users.map { |u| "• <strong>#{u[:name]}</strong> (<code>#{u[:email]}</code>) — #{u[:status].capitalize}" }.join("<br>")
    end

    stats = UserQueryTool.execute("get_user_statistics")
    "We have <strong>#{stats[:total_users]}</strong> registered users (#{stats[:active_users]} active, #{stats[:blocked_users]} blocked)."
  end

  def self.instant_knowledge_base(question)
    q = question.downcase.strip
    if q.match?(/\bc\b/) && (q.include?("language") || q.include?("know") || q.include?("what"))
      return "<strong>C</strong> is a foundational general-purpose procedural programming language developed by Dennis Ritchie in 1972, widely used for operating systems and embedded hardware."
    end
    KNOWLEDGE_BASE.each { |pattern, reply| return reply if q.match?(pattern) }
    nil
  end

  # External knowledge fallback (Gemini -> Cloud LLM -> Wikipedia)
  def self.fetch_fast_live_knowledge(prompt)
    api_key = fetch_api_key
    if api_key.present? && api_key.start_with?("AIza")
      res = call_gemini_fast(prompt, api_key)
      return res if res.present?
    end

    call_fast_cloud_llm(prompt) || call_wikipedia_summary(prompt)
  end

  def self.call_fast_cloud_llm(prompt)
    res = http_request("https://text.pollinations.ai/", method: :post, body: {
      messages: [
        { role: "system", content: "You are a concise, helpful AI assistant. Answer in 1 to 2 clear sentences." },
        { role: "user", content: prompt }
      ],
      model: "openai"
    })
    text = res&.body.to_s.strip
    text if res&.is_a?(Net::HTTPSuccess) && text.length > 2 && !text.start_with?("<!DOCTYPE", "<html")
  rescue StandardError
    nil
  end

  def self.call_wikipedia_summary(prompt)
    topic = prompt.downcase.gsub(/\A(do you know about|do you know|what is a|what is an|what is the|what is|who is|tell me about|explain)\s+/i, "").gsub(/[?!.]/, "").strip
    return nil if topic.blank? || topic.split.size > 4

    res = http_request("https://en.wikipedia.org/api/rest_v1/page/summary/#{CGI.escape(topic.tr(' ', '_'))}", headers: { "User-Agent" => "RailsAdminAssistant/1.0" })
    JSON.parse(res.body)["extract"].to_s.strip.presence if res&.is_a?(Net::HTTPSuccess)
  rescue StandardError
    nil
  end

  def self.call_gemini_fast(prompt, api_key)
    res = http_request("#{GEMINI_URL}?key=#{api_key}", method: :post, body: { contents: [{ parts: [{ text: prompt }] }] })
    return nil unless res&.is_a?(Net::HTTPSuccess)

    parts = (JSON.parse(res.body).dig("candidates", 0, "content", "parts") rescue nil) || []
    parts.map { |p| p["text"].to_s }.join.strip.presence
  rescue StandardError
    nil
  end

  # Shared HTTP helper
  def self.http_request(url_str, method: :get, body: nil, headers: {})
    uri = URI(url_str)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 2
    http.read_timeout = 4

    req = method == :post ? Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json") : Net::HTTP::Get.new(uri.request_uri)
    headers.each { |k, v| req[k] = v }
    req.body = body.to_json if body
    http.request(req)
  end

  def self.extract_prefixes(q)
    match_data = q.match(/(?:starting|beginning|starts|begins)\s+with\s+(?:the\s+)?(?:letter\s+|letters\s+)?(.+)/i)
    raw = match_data ? match_data[1] : q.split(/start|begin/i).last.to_s
    raw.scan(/[a-z0-9]+/i).map(&:downcase) - STOP_WORDS
  end

  def self.match_users_by_prefix(field, prefixes)
    User.pluck(:id, :name, :email).select do |_, n, e|
      val = (field == :name ? n : e).to_s.downcase
      prefixes.any? { |p| val.start_with?(p) }
    end
  end

  def self.is_database_query?(q)
    terms = %w[user users active blocked block status last_login last_seen registered table count how\ many]
    terms.any? { |t| q.match?(/\b#{Regexp.escape(t)}\b/i) } ||
      User.pluck(:name, :email).any? { |n, e| q.downcase.include?(n.to_s.downcase) || q.downcase.include?(e.to_s.downcase) }
  end

  def self.fetch_api_key
    @api_key ||= (ENV["GEMINI_API_KEY"].presence || read_local_env_file)
  end

  def self.read_local_env_file
    target = [Rails.root.join(".env"), Rails.root.join(".env.txt")].find { |p| File.exist?(p) }
    return nil unless target

    File.readlines(target, encoding: "bom|utf-8").each do |line|
      clean = line.strip.sub(/^\xEF\xBB\xBF/, "")
      return $1.strip.gsub(/\A["']|["']\z/, "") if clean =~ /\A(?:export\s+)?GEMINI_API_KEY\s*=\s*(.*)\z/i
    end
    nil
  end
end