class AiChatsController < ApplicationController
  # Handles incoming AI chat questions and commands
  def create
    question = params[:question].to_s.strip

    if question.blank?
      render json: { answer: "Please ask a valid question." }
    else
      begin
        result = GeminiService.ask(question)
        render json: result
      rescue StandardError => e
        Rails.logger.error("AI Chat Controller Error: #{e.message}")
        render json: { answer: "Backend Error: #{e.message}" }
      end
    end
  end
end