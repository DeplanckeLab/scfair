class StatsController < ApplicationController
  def index
    @sources = Source.all.order(:name)
    @categories = Dataset::CATEGORIES
    @stats = OntologyCoverage.all.group_by(&:source_id)
  end

  def failed_datasets
    @source = Source.find(params[:source_id])
    @datasets = @source.datasets
                      .where(status: :failed)
                      .includes(
                        :sexes, :cell_types, :tissues, :developmental_stages,
                        :organisms, :diseases, :technologies, :file_resources,
                        :study, :links
                      )
    
    render layout: false
  end
end
