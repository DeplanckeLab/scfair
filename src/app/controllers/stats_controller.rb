class StatsController < ApplicationController
  def index
    @sources = Source.all.order(:name)
    @categories = Dataset::CATEGORIES
    @stats = OntologyCoverage.all
  end
end
