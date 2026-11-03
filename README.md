# scFAIR: Single-Cell Genomics Data Standardization Initiative

## Overview

scFAIR is an initiative to standardize single-cell genomics data and promote findable, accessible, interoperable, and reusable (FAIR) single-cell data. Our goal is to build a collaborative platform that supports and disseminates open research data (ORD) practices within the single-cell genomics community. This platform will enable researchers to upload, annotate, and access single-cell data and associated metadata, ensuring that these data are useful to an increasing community of specialists and non-specialists.

## Background

Single-cell genomics has emerged as a transformative field within molecular biology, revolutionizing our understanding of cellular heterogeneity and paving the way for unprecedented insights into complex biological systems. As the quantity and diversity of single-cell data rapidly increase, the lack of clear reporting standards has led to multiple non-compatible datasets, limiting reusability. This presents challenges in making these data useful to the broader scientific community.

## Need for Standardization

To address these challenges, there is a critical need for:
- A centralized, standardized repository where researchers can collaboratively upload, annotate, and access single-cell data and associated metadata.
- Standardized methods for storing and annotating single-cell data, particularly regarding essential metadata. This includes:
  - Protocols
  - Normalization and pipeline characteristics
  - Cell type classifications and the methods used to classify them
  - Association between barcodes and annotations

Adopting systematic data-sharing practices and standards is integral to fostering transparency, reproducibility, and effective utilization of single-cell genomics data.

## Objectives

- Build a collaborative platform for sharing datasets and their metadata.
- Standardize the way data are shared across datasets.
- Promote communication and outreach to increase the relevance and implementation of these standards within the single-cell genomics community.

## Getting Started

To set up the project, follow these steps:

1. Create a `/data` folder in the root directory of the project.
2. Download the composite metazoan ontology file from the following link: [http://purl.obolibrary.org/obo/uberon/collected-metazoan.obo](http://purl.obolibrary.org/obo/uberon/collected-metazoan.obo).
3. Place the downloaded file in the `/data/scfair` folder.

After setting up the /data folder and placing the ontology file, run the following Rake commands in sequence:

    rake db:create && rake db:migrate
    rake 'obo:parse[/data/scfair/collected-metazoan.obo]'
    rake 'obo:parse[/data/scfair/cl.obo]'
    rake 'obo:parse[/data/scfair/efo.obo]'
    rake 'obo:parse[/data/scfair/fbbt.obo]'
    rake 'obo:parse[/data/scfair/fbdv.obo]'
    rake 'obo:parse[/data/scfair/hancestro-base.obo]'
    rake 'obo:parse[/data/scfair/hsapdv.obo]'
    rake 'obo:parse[/data/scfair/mmusdv.obo]'
    rake 'obo:parse[/data/scfair/mondo.obo]'
    rake 'obo:parse[/data/scfair/ncbitaxon.obo]'
    rake 'obo:parse[/data/scfair/pato.obo]'
    rake 'obo:parse[/data/scfair/uberon.obo]'
    rake 'obo:parse[/data/scfair/wbbt.obo]'
    rake 'obo:parse[/data/scfair/wbls.obo]'
    rake 'obo:parse[/data/scfair/zfa.obo]'
    rake scfair:setup

These commands will parse the ontology file, update the adjacency lists, and finally, update the API.

As an alternative to running the OBO parser on each ontology file, you can use the load_ontology.sh script to directly load a dump of the two ontology-related tables after adding the corresponding .csv files to the data directory.

## Operations

### Elasticsearch

The stack runs Elasticsearch from `docker-compose.yaml` (currently **9.5.5**). The Rails app uses the `elasticsearch` Ruby gem (9.5.x) and talks to the service at `ELASTICSEARCH_URL` (`http://elasticsearch:9200` inside Compose).

#### Upgrade Elasticsearch

1. **Back up data** (production persists to `/data/scfair/elasticsearch` on the host). Copy or snapshot that directory before upgrading on a live instance.

2. **Pull and restart the search service** from the project root:

   ```bash
   docker compose pull elasticsearch
   docker compose up -d elasticsearch
   ```

3. **Watch startup** until the healthcheck passes:

   ```bash
   docker compose logs -f elasticsearch
   curl -s http://localhost:9200
   ```

4. **Refresh the website image** if `Gemfile` / `Gemfile.lock` changed:

   ```bash
   docker compose exec website bundle install
   docker compose up -d website
   ```

5. **Smoke-test search** in the UI or via the app. If indices are missing or mappings fail after a major jump, rebuild search from the database:

   ```bash
   docker compose exec website rake index_db
   ```

   That runs `search:setup_datasets`, `search:setup_ontology_terms`, and full reindex tasks for ontology terms and datasets.

#### Test environment

Use the test Compose file (Elasticsearch on host port **9201**):

```bash
docker compose -f docker-compose.test.yaml pull elasticsearch
docker compose -f docker-compose.test.yaml up -d elasticsearch
```

#### If the node fails to start after upgrade

- Read the first error in `docker compose logs elasticsearch` (often incompatible data from an older major version).
- Restore the backup of `/data/scfair/elasticsearch`, or stop Elasticsearch, remove the data directory only after confirming you can rebuild from `rake index_db`, then start a fresh node and run `index_db` as above.

---

Thank you for being part of the scFAIR initiative! Together, we can make single-cell genomics data more findable, accessible, interoperable, and reusable.
