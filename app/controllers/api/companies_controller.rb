module Api
  class CompaniesController < ApplicationController
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

      companies = Company
        .where("name LIKE ?", "%#{sanitize_sql_like(query)}%")
        .order(:name)
        .limit(20)
        .pluck(:id, :name)
        .map { |id, name| { id: id, name: name } }

      render json: companies
    end
  end
end
