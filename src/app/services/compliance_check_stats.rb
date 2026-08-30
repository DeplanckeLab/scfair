class ComplianceCheckStats
  StatusCounts = Struct.new(:passed, :failed, :warning, :skipped, :unknown, keyword_init: true) do
    def total
      passed + failed + warning + skipped + unknown
    end

    def evaluated
      passed + failed + warning
    end

    def pass_rate
      return nil if evaluated.zero?

      (passed.to_f / evaluated * 100).round(1)
    end
  end

  CheckRow = Struct.new(:group_id, :group_label, :field, :title, :by_column, keyword_init: true)
  Column = Struct.new(:key, :name, :logo, :source_id, keyword_init: true)
  ColumnCoverage = Struct.new(
    :column,
    :file_resources_count,
    :checked_count,
    :passed_count,
    :failed_count,
    :failed_run_count,
    keyword_init: true
  )

  FIELD_PREFIX_MAP = [
    ["/col_attrs/", "obs/"],
    ["/row_attrs/", "var/"],
    ["/attrs/", "uns/"],
    ["obs/", "obs/"],
    ["var/", "var/"],
    ["uns/", "uns/"]
  ].freeze

  EQUIVALENT_FIELDS = {
    "X" => "matrix",
    "dimensions" => "matrix"
  }.freeze

  EQUIVALENT_GROUPS = {
    "h5ad.matrix_encoding" => "matrix_encoding",
    "loom.matrix_encoding" => "matrix_encoding",
    "h5ad.structure" => "structure",
    "loom.structure" => "structure"
  }.freeze

  GROUP_LABELS = {
    "matrix_encoding" => "Matrix encoding checks",
    "structure" => "File structural integrity"
  }.freeze

  ASAP_COLUMN_KEY = "asap".freeze
  ASAP_V8_COLUMN_KEY = "asap_v8".freeze

  def self.build
    new.build
  end

  def build
    {
      columns: columns,
      coverage: coverage_by_column,
      checks: check_rows
    }
  end

  private

  def sources
    @sources ||= Source.order(:name).to_a
  end

  def columns
    @columns ||= sources.flat_map do |source|
      if source.slug == "asap"
        [
          Column.new(key: ASAP_COLUMN_KEY, name: "ASAP", logo: source.logo, source_id: source.id.to_s),
          Column.new(key: ASAP_V8_COLUMN_KEY, name: "ASAP v8", logo: source.logo, source_id: source.id.to_s)
        ]
      else
        [Column.new(key: source.id.to_s, name: source.name, logo: source.logo, source_id: source.id.to_s)]
      end
    end
  end

  def coverage_by_column
    sql = <<~SQL
      SELECT
        CASE
          WHEN s.slug = 'asap' AND d.source_version = 'v8' THEN 'asap_v8'
          WHEN s.slug = 'asap' THEN 'asap'
          ELSE s.id::text
        END AS column_key,
        COUNT(DISTINCT fr.id) AS file_resources_count,
        COUNT(DISTINCT cc.id) AS checked_count,
        COUNT(DISTINCT cc.id) FILTER (WHERE cc.passed IS TRUE) AS passed_count,
        COUNT(DISTINCT cc.id) FILTER (WHERE cc.passed IS FALSE AND cc.status = 'completed') AS failed_count,
        COUNT(DISTINCT cc.id) FILTER (WHERE cc.status = 'failed') AS failed_run_count
      FROM sources s
      LEFT JOIN datasets d ON d.source_id = s.id
      LEFT JOIN file_resources fr ON fr.dataset_id = d.id
      LEFT JOIN compliance_checks cc ON cc.file_resource_id = fr.id
      GROUP BY column_key
    SQL

    rows = ApplicationRecord.connection.select_all(sql).index_by { |row| row["column_key"].to_s }

    columns.map do |column|
      row = rows[column.key] || {}
      ColumnCoverage.new(
        column: column,
        file_resources_count: row["file_resources_count"].to_i,
        checked_count: row["checked_count"].to_i,
        passed_count: row["passed_count"].to_i,
        failed_count: row["failed_count"].to_i,
        failed_run_count: row["failed_run_count"].to_i
      )
    end
  end

  def check_rows
    sql = <<~SQL
      SELECT
        CASE
          WHEN s.slug = 'asap' AND d.source_version = 'v8' THEN 'asap_v8'
          WHEN s.slug = 'asap' THEN 'asap'
          ELSE s.id::text
        END AS column_key,
        g->>'id' AS group_id,
        g->>'label' AS group_label,
        item->>'field' AS field,
        COALESCE(item->'detail'->>'title', item->>'field') AS title,
        COALESCE(item->>'status', item->'detail'->>'status', 'unknown') AS status,
        COUNT(*) AS n
      FROM compliance_checks cc
      JOIN file_resources fr ON fr.id = cc.file_resource_id
      JOIN datasets d ON d.id = fr.dataset_id
      JOIN sources s ON s.id = d.source_id
      CROSS JOIN LATERAL jsonb_array_elements(cc.result->'check_groups') g
      CROSS JOIN LATERAL jsonb_array_elements(COALESCE(g->'items', '[]'::jsonb)) item
      WHERE jsonb_exists(cc.result, 'check_groups')
        AND jsonb_typeof(cc.result->'check_groups') = 'array'
      GROUP BY column_key, g->>'id', g->>'label', item->>'field', COALESCE(item->'detail'->>'title', item->>'field'), COALESCE(item->>'status', item->'detail'->>'status', 'unknown')
      ORDER BY g->>'id', item->>'field', column_key
    SQL

    grouped = {}

    ApplicationRecord.connection.select_all(sql).each do |row|
      canonical_group_id = normalize_group_id(row["group_id"])
      canonical_field = normalize_field(row["field"])
      key = [canonical_group_id, canonical_field]

      check = grouped[key] ||= {
        group_id: canonical_group_id,
        group_label: GROUP_LABELS[canonical_group_id] || row["group_label"],
        field: canonical_field,
        title: row["title"],
        original_fields: [],
        by_column: {}
      }

      check[:original_fields] << row["field"].to_s if row["field"].present?
      check[:title] = preferred_title(check[:title], row["title"])
      check[:group_label] = GROUP_LABELS[canonical_group_id] || preferred_group_label(check[:group_label], row["group_label"])

      column_key = row["column_key"].to_s
      counts = check[:by_column][column_key] ||= StatusCounts.new(passed: 0, failed: 0, warning: 0, skipped: 0, unknown: 0)
      status = row["status"].to_s
      amount = row["n"].to_i

      case status
      when "passed" then counts.passed += amount
      when "failed" then counts.failed += amount
      when "warning" then counts.warning += amount
      when "skipped" then counts.skipped += amount
      else counts.unknown += amount
      end
    end

    grouped.values
           .sort_by { |check| [check[:group_id].to_s, check[:field].to_s] }
           .map do |check|
             CheckRow.new(
               group_id: check[:group_id],
               group_label: check[:group_label],
               field: display_field(check[:original_fields], check[:field]),
               title: check[:title],
               by_column: check[:by_column]
             )
           end
  end

  def normalize_group_id(group_id)
    value = group_id.to_s
    return EQUIVALENT_GROUPS[value] if EQUIVALENT_GROUPS.key?(value)

    value
  end

  def normalize_field(field)
    value = field.to_s
    return EQUIVALENT_FIELDS[value] if EQUIVALENT_FIELDS.key?(value)

    FIELD_PREFIX_MAP.each do |from_prefix, to_prefix|
      return "#{to_prefix}#{value.delete_prefix(from_prefix)}" if value.start_with?(from_prefix)
    end

    value
  end

  def preferred_title(current, incoming)
    return incoming if current.blank?
    return current if incoming.blank?
    return incoming if incoming.length > current.length

    current
  end

  def preferred_group_label(current, incoming)
    return incoming if current.blank?
    return current if incoming.blank?
    return incoming if current.match?(/AnnData|Loom|h5ad/i) && !incoming.match?(/AnnData|Loom|h5ad/i)

    current
  end

  def display_field(original_fields, canonical_field)
    unique_fields = original_fields.map(&:to_s).reject(&:blank?).uniq
    return canonical_field if unique_fields.empty?
    return unique_fields.first if unique_fields.one?

    h5ad_like = unique_fields.find { |field| field.match?(%r{\A(obs|var|uns)/}) || field == "X" }
    loom_like = unique_fields.find { |field| field.start_with?("/") || field == "dimensions" }

    if h5ad_like && loom_like && h5ad_like != loom_like
      "#{h5ad_like} | #{loom_like}"
    else
      unique_fields.sort.join(" | ")
    end
  end
end
