class StatsController < ApplicationController
  def index
    @sources = Source.all.order(:name)
    @categories = Dataset::CATEGORIES
    @stats = OntologyCoverage.all.group_by(&:source_id)
  end
end
