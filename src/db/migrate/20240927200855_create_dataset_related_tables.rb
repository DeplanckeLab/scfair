class CreateDatasetRelatedTables < ActiveRecord::Migration[7.0]
  def up
    drop_table :datasets if table_exists?(:datasets)

    create_table :datasets, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :collection_id, null: false
      t.string :source_reference_id, null: false
      t.references :source, type: :uuid, null: false, foreign_key: true
      t.string :source_url, null: false # previously link_to_dataset
      t.string :explorer_url, null: false # previously link_to_explore_data
      t.string :doi, index: true
      t.integer :cell_count, null: false, default: 0, index: true
      t.string :parser_hash, null: false
      t.integer :links_count, default: 0, null: false
      t.string :status, default: "processing", null: false
      t.jsonb :notes, default: {}

      t.timestamps

      t.index :status
      t.index :source_reference_id, unique: true
    end

    create_table :sexes, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :name, null: false
      t.references :ontology_term, type: :uuid, null: true
      t.timestamps

      t.index [:name, :ontology_term_id], unique: true
    end

    create_table :datasets_sexes, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :sex, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :sex_id], unique: true
    end

    create_table :cell_types, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :name, null: false
      t.references :ontology_term, type: :uuid, null: true
      t.timestamps

      t.index [:name, :ontology_term_id], unique: true
    end

    create_table :cell_types_datasets, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :cell_type, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :cell_type_id], unique: true
    end

    create_table :tissues, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :name, null: false
      t.references :ontology_term, type: :uuid, null: true
      t.timestamps

      t.index [:name, :ontology_term_id], unique: true
    end

    create_table :datasets_tissues, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :tissue, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :tissue_id], unique: true
    end

    create_table :developmental_stages, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :name, null: false
      t.references :ontology_term, type: :uuid, null: true
      t.timestamps

      t.index [:name, :ontology_term_id], unique: true
    end

    create_table :datasets_developmental_stages, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :developmental_stage, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :developmental_stage_id], unique: true, name: "index_datasets_dev_stages_on_dataset_id_and_dev_stage_id"
    end

    create_table :organisms, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :name, null: false
      t.references :ontology_term, type: :uuid, null: true
      t.timestamps

      t.index [:name, :ontology_term_id], unique: true
    end

    create_table :datasets_organisms, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :organism, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :organism_id], unique: true
    end

    create_table :diseases, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :name, null: false
      t.references :ontology_term, type: :uuid, null: true
      t.timestamps

      t.index [:name, :ontology_term_id], unique: true
    end

    create_table :datasets_diseases, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :disease, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :disease_id], unique: true
    end

    create_table :technologies, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :name, null: false
      t.references :ontology_term, type: :uuid, null: true
      t.timestamps

      t.index [:name, :ontology_term_id], unique: true
    end

    create_table :datasets_technologies, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :technology, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :technology_id], unique: true
    end

    create_table :suspension_types, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :name, null: false
      t.references :ontology_term, type: :uuid, null: true
      t.timestamps

      t.index [:name], unique: true
    end

    create_table :datasets_suspension_types, id: false, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.references :suspension_type, type: :uuid, null: false, foreign_key: true

      t.index [:dataset_id, :suspension_type_id], unique: true, name: "idx_ds_st"
    end

    # previously processed data
    create_table :file_resources, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.string :url, null: false
      t.string :filetype, null: false
      t.timestamps
      t.index [:dataset_id, :url, :filetype], unique: true
    end

    add_reference :ext_sources, :dataset, index: true
  end

  def down
    if column_exists?(:ext_sources, :dataset_id)
      remove_reference :ext_sources, :dataset
    end

    drop_table :file_resources if table_exists?(:file_resources)
    drop_table :datasets_technologies if table_exists?(:datasets_technologies)
    drop_table :datasets_diseases if table_exists?(:datasets_diseases)
    drop_table :datasets_organisms if table_exists?(:datasets_organisms)
    drop_table :datasets_developmental_stages if table_exists?(:datasets_developmental_stages)
    drop_table :datasets_tissues if table_exists?(:datasets_tissues)
    drop_table :cell_types_datasets if table_exists?(:cell_types_datasets)
    drop_table :datasets_sexes if table_exists?(:datasets_sexes)
    drop_table :datasets_suspension_types if table_exists?(:datasets_suspension_types)

    drop_table :technologies if table_exists?(:technologies)
    drop_table :diseases if table_exists?(:diseases)
    drop_table :organisms if table_exists?(:organisms)
    drop_table :developmental_stages if table_exists?(:developmental_stages)
    drop_table :tissues if table_exists?(:tissues)
    drop_table :cell_types if table_exists?(:cell_types)
    drop_table :sexes if table_exists?(:sexes)
    drop_table :suspension_types if table_exists?(:suspension_types)
    drop_table :dataset_links if table_exists?(:dataset_links)
    drop_table :datasets if table_exists?(:datasets)
  end
end
