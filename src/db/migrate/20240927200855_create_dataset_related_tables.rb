class CreateDatasetRelatedTables < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' # Enable the pgcrypto extension for UUID generation

    create_table :datasets, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :collection_id
      t.string :dataset_id
      t.string :source_name
      t.string :source_url # previously link_to_dataset
      t.string :data_explorer_url # previously link_to_explore_data
      t.string :doi
      t.integer :number_of_cells
      t.string :parser_hash
      t.timestamps
    end

    create_table :sexes, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name
      t.string :ontology_term_id, index: true
      t.timestamps
    end

    create_table :datasets_sexes, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :sex, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :sex_id], unique: true
    end

    create_table :cell_types, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name
      t.string :ontology_term_id, index: true
      t.timestamps
    end

    create_table :datasets_cell_types, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :cell_type, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :cell_type_id], unique: true
    end

    create_table :tissues, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name
      t.string :ontology_term_id, index: true
      t.timestamps
    end

    create_table :datasets_tissues, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :tissue, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :tissue_id], unique: true
    end

    create_table :developmental_stages, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name
      t.string :ontology_term_id, index: true
      t.timestamps
    end

    create_table :datasets_developmental_stages, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :developmental_stage, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :developmental_stage_id], unique: true
    end

    create_table :organisms, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name
      t.string :ontology_term_id, index: true
      t.timestamps
    end

    create_table :datasets_organisms, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :organism, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :organism_id], unique: true
    end

    create_table :diseases, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :name
      t.string :ontology_term_id, index: true
      t.timestamps
    end

    create_table :datasets_diseases, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :disease, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :disease_id], unique: true
    end

    create_table :assay_info, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :info
      t.string :ontology_term_id, index: true
      t.timestamps
    end

    create_table :datasets_assay_info, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :assay_info, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :assay_info_id], unique: true
    end

    # previously processed data
    create_table :files, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :url
      t.timestamps
    end

    create_table :datasets_files, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :file, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :file_id], unique: true
    end

    create_table :datasets_ext_sources, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :ext_source, type: :uuid, null: false, foreign_key: true
      t.index [:dataset_id, :ext_source_id], unique: true
    end
  end
end
