# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_09_074614) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "uuid-ossp"

  create_table "cell_types", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.uuid "ontology_term_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "ontology_term_id"], name: "index_cell_types_on_name_and_ontology_term_id", unique: true
    t.index ["ontology_term_id"], name: "index_cell_types_on_ontology_term_id"
  end

  create_table "cell_types_datasets", id: false, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.uuid "cell_type_id", null: false
    t.index ["cell_type_id"], name: "index_cell_types_datasets_on_cell_type_id"
    t.index ["dataset_id", "cell_type_id"], name: "index_cell_types_datasets_on_dataset_id_and_cell_type_id", unique: true
    t.index ["dataset_id"], name: "index_cell_types_datasets_on_dataset_id"
  end

  create_table "dataset_links", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.string "url", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_id"], name: "index_dataset_links_on_dataset_id"
  end

  create_table "datasets", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "collection_id", null: false
    t.string "source_reference_id", null: false
    t.uuid "source_id", null: false
    t.string "source_url", null: false
    t.string "explorer_url", null: false
    t.string "doi"
    t.integer "cell_count", default: 0, null: false
    t.string "parser_hash", null: false
    t.integer "links_count", default: 0, null: false
    t.string "status", default: "processing", null: false
    t.jsonb "notes", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cell_count"], name: "index_datasets_on_cell_count"
    t.index ["doi"], name: "index_datasets_on_doi"
    t.index ["source_id"], name: "index_datasets_on_source_id"
    t.index ["source_reference_id"], name: "index_datasets_on_source_reference_id", unique: true
    t.index ["status"], name: "index_datasets_on_status"
  end

  create_table "datasets_developmental_stages", id: false, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.uuid "developmental_stage_id", null: false
    t.index ["dataset_id", "developmental_stage_id"], name: "index_datasets_dev_stages_on_dataset_id_and_dev_stage_id", unique: true
    t.index ["dataset_id"], name: "index_datasets_developmental_stages_on_dataset_id"
    t.index ["developmental_stage_id"], name: "index_datasets_developmental_stages_on_developmental_stage_id"
  end

  create_table "datasets_diseases", id: false, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.uuid "disease_id", null: false
    t.index ["dataset_id", "disease_id"], name: "index_datasets_diseases_on_dataset_id_and_disease_id", unique: true
    t.index ["dataset_id"], name: "index_datasets_diseases_on_dataset_id"
    t.index ["disease_id"], name: "index_datasets_diseases_on_disease_id"
  end

  create_table "datasets_organisms", id: false, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.uuid "organism_id", null: false
    t.index ["dataset_id", "organism_id"], name: "index_datasets_organisms_on_dataset_id_and_organism_id", unique: true
    t.index ["dataset_id"], name: "index_datasets_organisms_on_dataset_id"
    t.index ["organism_id"], name: "index_datasets_organisms_on_organism_id"
  end

  create_table "datasets_sexes", id: false, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.uuid "sex_id", null: false
    t.index ["dataset_id", "sex_id"], name: "index_datasets_sexes_on_dataset_id_and_sex_id", unique: true
    t.index ["dataset_id"], name: "index_datasets_sexes_on_dataset_id"
    t.index ["sex_id"], name: "index_datasets_sexes_on_sex_id"
  end

  create_table "datasets_technologies", id: false, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.uuid "technology_id", null: false
    t.index ["dataset_id", "technology_id"], name: "index_datasets_technologies_on_dataset_id_and_technology_id", unique: true
    t.index ["dataset_id"], name: "index_datasets_technologies_on_dataset_id"
    t.index ["technology_id"], name: "index_datasets_technologies_on_technology_id"
  end

  create_table "datasets_tissues", id: false, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.uuid "tissue_id", null: false
    t.index ["dataset_id", "tissue_id"], name: "index_datasets_tissues_on_dataset_id_and_tissue_id", unique: true
    t.index ["dataset_id"], name: "index_datasets_tissues_on_dataset_id"
    t.index ["tissue_id"], name: "index_datasets_tissues_on_tissue_id"
  end

  create_table "developmental_stages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.uuid "ontology_term_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "ontology_term_id"], name: "index_developmental_stages_on_name_and_ontology_term_id", unique: true
    t.index ["ontology_term_id"], name: "index_developmental_stages_on_ontology_term_id"
  end

  create_table "diseases", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.uuid "ontology_term_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "ontology_term_id"], name: "index_diseases_on_name_and_ontology_term_id", unique: true
    t.index ["ontology_term_id"], name: "index_diseases_on_ontology_term_id"
  end

  create_table "ext_sources", force: :cascade do |t|
    t.string "url_mask"
    t.string "name"
    t.string "description"
    t.string "id_regexp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "file_resources", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.string "url", null: false
    t.string "filetype", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_id", "url", "filetype"], name: "index_file_resources_on_dataset_id_and_url_and_filetype", unique: true
    t.index ["dataset_id"], name: "index_file_resources_on_dataset_id"
  end

  create_table "journals", force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ontology_coverage", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "source_id", null: false
    t.string "category"
    t.integer "records_count", default: 0, null: false
    t.integer "relationships_count", default: 0, null: false
    t.integer "records_with_ontology_count", default: 0, null: false
    t.integer "records_missing_ontology_count", default: 0, null: false
    t.integer "parsing_issues_count", default: 0, null: false
    t.boolean "manually_curated", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_ontology_coverage_on_category"
    t.index ["source_id", "category"], name: "index_ontology_coverage_on_source_id_and_category", unique: true
    t.index ["source_id"], name: "index_ontology_coverage_on_source_id"
  end

  create_table "ontology_term_relationships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "parent_id", null: false
    t.uuid "child_id", null: false
    t.string "relationship_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["child_id"], name: "index_ontology_term_relationships_on_child_id"
    t.index ["parent_id", "child_id"], name: "index_ontology_term_relationships_on_parent_id_and_child_id", unique: true
  end

  create_table "ontology_terms", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.citext "identifier", null: false
    t.citext "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_ontology_terms_on_identifier", unique: true
    t.index ["name"], name: "index_ontology_terms_on_name"
  end

  create_table "organisms", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.uuid "ontology_term_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "ontology_term_id"], name: "index_organisms_on_name_and_ontology_term_id", unique: true
    t.index ["ontology_term_id"], name: "index_organisms_on_ontology_term_id"
  end

  create_table "parsing_issues", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "dataset_id", null: false
    t.string "resource"
    t.string "value"
    t.string "external_reference_id"
    t.string "message"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dataset_id"], name: "index_parsing_issues_on_dataset_id"
  end

  create_table "sexes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.uuid "ontology_term_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "ontology_term_id"], name: "index_sexes_on_name_and_ontology_term_id", unique: true
    t.index ["ontology_term_id"], name: "index_sexes_on_ontology_term_id"
  end

  create_table "sources", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "logo"
    t.integer "completed_datasets_count", default: 0, null: false
    t.integer "failed_datasets_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_sources_on_name", unique: true
    t.index ["slug"], name: "index_sources_on_slug", unique: true
  end

  create_table "studies", force: :cascade do |t|
    t.text "title"
    t.text "first_author"
    t.text "authors"
    t.text "authors_json"
    t.text "abstract"
    t.bigint "journal_id"
    t.text "volume"
    t.text "issue"
    t.text "doi"
    t.integer "year"
    t.text "comment"
    t.text "description"
    t.datetime "published_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["doi"], name: "index_studies_on_doi", unique: true
    t.index ["journal_id"], name: "index_studies_on_journal_id"
  end

  create_table "technologies", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.uuid "ontology_term_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "ontology_term_id"], name: "index_technologies_on_name_and_ontology_term_id", unique: true
    t.index ["ontology_term_id"], name: "index_technologies_on_ontology_term_id"
  end

  create_table "tissues", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.citext "name", null: false
    t.uuid "ontology_term_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "ontology_term_id"], name: "index_tissues_on_name_and_ontology_term_id", unique: true
    t.index ["ontology_term_id"], name: "index_tissues_on_ontology_term_id"
  end

  add_foreign_key "cell_types_datasets", "cell_types"
  add_foreign_key "cell_types_datasets", "datasets"
  add_foreign_key "dataset_links", "datasets"
  add_foreign_key "datasets", "sources"
  add_foreign_key "datasets_developmental_stages", "datasets"
  add_foreign_key "datasets_developmental_stages", "developmental_stages"
  add_foreign_key "datasets_diseases", "datasets"
  add_foreign_key "datasets_diseases", "diseases"
  add_foreign_key "datasets_organisms", "datasets"
  add_foreign_key "datasets_organisms", "organisms"
  add_foreign_key "datasets_sexes", "datasets"
  add_foreign_key "datasets_sexes", "sexes"
  add_foreign_key "datasets_technologies", "datasets"
  add_foreign_key "datasets_technologies", "technologies"
  add_foreign_key "datasets_tissues", "datasets"
  add_foreign_key "datasets_tissues", "tissues"
  add_foreign_key "file_resources", "datasets"
  add_foreign_key "ontology_coverage", "sources"
  add_foreign_key "studies", "journals"
end
