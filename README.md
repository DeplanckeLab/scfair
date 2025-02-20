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

    rake db:create && rake db:migrate && rake db:seed
    rake fix:organisms
    rake 'obo:parse[/data/scfair/collected-metazoan.obo]'
    rake 'obo:parse[/data/scfair/efo.obo]'
    rake 'obo:parse[/data/scfair/hsapdv.obo]'
    rake api_updates
    rake load_studies
    rake load_ext_sources

These commands will parse the ontology file, update the adjacency lists, and finally, update the API.

---

Thank you for being part of the scFAIR initiative! Together, we can make single-cell genomics data more findable, accessible, interoperable, and reusable.