class CreateDatasetRelatedTables < ActiveRecord::Migration[7.0]
  def change
    rename_table :datasets, :datasets_old

    enable_extension "uuid-ossp"

    create_table :datasets, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :collection_id, null: false
      t.string :source_reference_id, null: false
      t.string :source_name, null: false, index: true
      t.string :source_url, null: false # previously link_to_dataset
      t.string :explorer_url, null: false # previously link_to_explore_data
      t.string :doi
      t.integer :cell_count, null: false, default: 0, index: true
      t.string :parser_hash, null: false
      t.timestamps
    end

    create_table :sexes, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name, null: false
      t.string :ontology_term_id, index: true
      t.timestamps

      t.index :name, unique: true
    end

    create_table :datasets_sexes, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :sex, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :sex_id], unique: true
    end

    create_table :cell_types, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name, null: false
      t.string :ontology_term_id, index: true
      t.timestamps

      t.index :name, unique: true
    end

    create_table :cell_types_datasets, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :cell_type, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :cell_type_id], unique: true
    end

    create_table :tissues, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name, null: false
      t.string :ontology_term_id, index: true
      t.timestamps

      t.index :name, unique: true
    end

    create_table :datasets_tissues, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :tissue, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :tissue_id], unique: true
    end

    create_table :developmental_stages, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name, null: false
      t.string :ontology_term_id, index: true
      t.timestamps

      t.index :name, unique: true
    end

    create_table :datasets_developmental_stages, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :developmental_stage, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :developmental_stage_id], unique: true, name: "index_datasets_dev_stages_on_dataset_id_and_dev_stage_id"
    end

    create_table :organisms, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name, null: false
      t.string :ontology_term_id, index: true
      t.timestamps

      t.index :name, unique: true
    end

    create_table :datasets_organisms, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :organism, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :organism_id], unique: true
    end

    create_table :diseases, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name, null: false
      t.string :ontology_term_id, index: true
      t.timestamps

      t.index :name, unique: true
    end

    create_table :datasets_diseases, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :disease, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :disease_id], unique: true
    end

    create_table :technologies, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :protocol_name, null: false
      t.string :ontology_term_id, index: true
      t.timestamps

      t.index :protocol_name, unique: true
    end

    create_table :datasets_technologies, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :technology, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :technology_id], unique: true
    end

    # previously processed data
    create_table :file_resources, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.string :url, null: false
      t.integer :filetype, default: 0
      t.timestamps
    end

    add_reference :ext_sources, :dataset, null: false, index: true
  end
end
