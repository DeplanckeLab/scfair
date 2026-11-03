class StatsController < ApplicationController
  def index
    @sources = Source.all.order(:name)
    @categories = Dataset::CATEGORIES
    category_order = @categories.map(&:name)
    @stats = OntologyCoverage.all.group_by(&:source_id).transform_values do |records|
      records.sort_by { |record| category_order.index(record.category) || Float::INFINITY }
    end
  end

  def compliance
    load_compliance_stats(include_all: false)
  end

  def compliance_all
    load_compliance_stats(include_all: true)
    render :compliance
  end

  def failing_check_datasets
    @column_key = params.require(:column_key)
    @group_id = params.require(:group_id)
    @field = params.require(:field)
    @title = params[:title].presence || @field
    @column_name = params[:column_name].presence || @column_key

    @failing_datasets = ::ComplianceCheckStats.failing_datasets(
      column_key: @column_key,
      group_id: @group_id,
      field: @field
    )

    render layout: false, formats: [:html]
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

  private

  def load_compliance_stats(include_all:)
    stats = ::ComplianceCheck.stats_for_page(include_all: include_all)
    @include_all = include_all
    @columns = stats[:columns]
    @coverage = stats[:coverage]
    @checks = stats[:checks]
  end
end
