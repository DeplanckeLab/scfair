class StatsController < ApplicationController
  def index
    stats = ::ComplianceCheck.stats_for_page
    @columns = stats[:columns]
    @coverage = stats[:coverage]
    @checks = stats[:checks]
  end

  def failed_datasets
    @source = Source.find(params[:source_id])
    @datasets = @source.datasets
                      .where(status: :failed)
                      .includes(
                        :sexes, :cell_types, :tissues, :developmental_stages,
                        :organisms, :diseases, :technologies,
                        { file_resources: :compliance_checks },
                        :study, :links
                      )

    render layout: false, formats: [:html]
  end

  def parsing_issues
    @source = Source.find(params[:source_id])
    @category = params[:category]
    @category_class = Dataset::CATEGORIES.find { |c| c.name.downcase == @category.downcase }

    parsing_issues_filter = { status: [:pending, :processing] }
    if @category_class
      parsing_issues_filter[:resource] = @category_class.name
    end

    dataset_ids = @source.datasets
                         .joins(:parsing_issues)
                         .where(parsing_issues: parsing_issues_filter)
                         .select(:id)
                         .distinct
                         .pluck(:id)

    @datasets = Dataset.where(id: dataset_ids)
                      .includes(:source, :study, { file_resources: :compliance_checks })
                      .preload(
                        :sexes, :cell_types, :tissues, :developmental_stages,
                        :organisms, :diseases, :technologies, :links
                      )

    @parsing_issues_by_dataset = ParsingIssue
                                   .where(dataset_id: dataset_ids)
                                   .where(parsing_issues_filter)
                                   .group_by(&:dataset_id)

    render layout: false, formats: [:html]
  end
end
