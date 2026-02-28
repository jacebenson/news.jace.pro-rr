module Api
  class ParticipantsController < ApplicationController
    def search
      unless current_user&.admin?
        render json: [], status: :unauthorized
        return
      end

      query = params[:q].to_s.strip
      if query.length < 2
        render json: []
        return
      end

      participants = Participant
        .includes(:company)
        .where("name LIKE ? OR title LIKE ?", "%#{sanitize_sql_like(query)}%", "%#{sanitize_sql_like(query)}%")
        .order(:name)
        .limit(20)

      # Exclude specific participant if provided
      if params[:exclude].present?
        participants = participants.where.not(id: params[:exclude])
      end

      results = participants.map do |p|
        {
          id: p.id,
          name: p.name,
          title: p.title,
          company: p.company&.name || p.company_name
        }
      end

      render json: results
    end
  end
end
