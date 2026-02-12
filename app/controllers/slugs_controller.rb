class SlugsController < ApplicationController
  def show
    slug = params[:slug]

    # Try to find a participant with this slug
    participant = Participant.find_by_slug(slug)
    if participant
      redirect_to who_path(name: participant.slug)
      return
    end

    # Try to find a company
    company = Company.where("LOWER(name) = ?", slug.downcase).first
    if company
      if company.is_partner?
        redirect_to partners_search_path(search: company.name)
      else
        redirect_to admin_companies_path(search: company.name)
      end
      return
    end

    # Not found
    redirect_to items_path, alert: "Page not found"
  end
end
