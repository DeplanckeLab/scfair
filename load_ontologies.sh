sudo docker-compose -f docker-compose.yaml exec -T postgres \
  sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\copy ontology_terms(id,identifier,name,description,created_at,updated_at,synonyms) FROM STDIN WITH (FORMAT csv, HEADER true)"' \
  < ./data/ontology_terms.csv

sudo docker-compose -f docker-compose.yaml exec -T postgres \
  sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\copy ontology_term_relationships(id,parent_id,child_id,relationship_type,created_at,updated_at) FROM STDIN WITH (FORMAT csv, HEADER true)"' \
  < ./data/ontology_term_relationships.csv
