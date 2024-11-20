ext_sources = [
  {
    url_mask: "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=#ID",
    name: "GEO series",
    description: "GEO series",
    id_regexp: "^GSE\\d+$"
  },
  {
    url_mask: "https://www.protocols.io/view/#ID",
    name: "protocols.io",
    description: "Protocols",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://cellxgene.cziscience.com/collections/#ID",
    name: "CELLxGENE collection",
    description: "CELLxGENE collection",
    id_regexp: "^[\\d\\w\\-]+$"
  },
  {
    url_mask: "https://explore.data.humancellatlas.org/projects/#ID https://data.humancellatlas.org/explore/projects/#ID",
    name: "HumanCellAtlas",
    description: "HumanCellAtlas",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://hubmapconsortium.org/",
    name: "HubMap consortium",
    description: "HubMap consortium"
  },
  {
    url_mask: "https://atlas.kpmp.org/explorer",
    name: "KPMP atlas",
    description: "KPMP atlas"
  },
  {
    url_mask: "https://www.kpmp.org/",
    name: "KPMP website",
    description: "KPMP website"
  },
  {
    url_mask: "https://actagingresearch.org/",
    name: "Adult Changes in Thought Study",
    description: "Adult Changes in Thought Study"
  },
  {
    url_mask: "https://adknowledgeportal.synapse.org/Explore/Studies/DetailsPage/StudyData?Study=#ID",
    name: "AD knowledge portal",
    description: "AD knowledge portal",
    id_regexp: "^syn\\d+$"
  },
  {
    url_mask: "http://depts.washington.edu/mbwc/adrc",
    name: "Alzheimer's Disease Research Center",
    description: "Alzheimer's Disease Research Center"
  },
  {
    url_mask: "https://dlmp.uw.edu/research-labs/keene/BRaIN-lab",
    name: "BRaIN-lab",
    description: "BRaIN-lab"
  },
  {
    url_mask: "https://portal.brain-map.org/explore/#ID",
    name: "Allen Brain Map",
    description: "Allen Brain Map",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://registry.opendata.aws/#ID",
    name: "AWS Open Data",
    description: "Registry of Open Data on AWS",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://www.synapse.org/#ID",
    name: "synapse.org",
    description: "synapse.org",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://github.com/#ID http://www.github.com/#ID",
    name: "Github",
    description: "Github",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://www.ebi.ac.uk/biostudies/arrayexpress/studies/#ID https://www.ebi.ac.uk/arrayexpress/experiments/#ID",
    name: "ArrayExpress BioStudies",
    description: "ArrayExpress BioStudies",
    id_regexp: "^E-MTAB-\\d+$"
  },
  {
    url_mask: "https://assets.nemoarchive.org/#ID http://data.nemoarchive.org/#ID",
    name: "NeMo archive",
    description: "The Neuroscience Multi-omic Data Archive",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://portal.brain-map.org/atlases-and-data/#ID",
    name: "Allen Brain Map Atlases",
    description: "Allen Brain Map Atlases",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://hq-1.gitbook.io/mc",
    name: "YAP",
    description: "YAP"
  },
  {
    url_mask: "http://neomorph.salk.edu/mouse_brain.php",
    name: "Mouse CEMBA Brain",
    description: "Mouse CEMBA Brain"
  },
  {
    url_mask: "http://neomorph.salk.edu/omb/",
    name: "Brain Cell Methylation Viewer",
    description: "Brain Cell Methylation Viewer"
  },
  {
    url_mask: "https://osf.io/rac5w/",
    name: "OSFHome Single Cell CHIP",
    description: "OSFHome Single Cell CHIP"
  },
  {
    url_mask: "https://www.ebi.ac.uk/biostudies/bioimages/studies/#ID",
    name: "Bioimage Archive",
    description: "Bioimage Archive",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://cells.ucsc.edu/?ds=#ID http://cells.ucsc.edu/?ds=#ID https://#ID.cells.ucsc.edu/",
    name: "UCSC Cell Browser",
    description: "UCSC Cell Browser",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://#ID.ds.czbiohub.org/",
    name: "CZ BioHub Portal",
    description: "CZ BioHub Portal",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://#ID.cellgeni.sanger.ac.uk/",
    name: "Sanger Dataset",
    description: "Sanger Dataset",
    id_regexp: "^.+?"
  },
  {
    url_mask: "https://www.hubrecht.eu/research-groups/van-oudenaarden-group/",
    name: "van Oudenaarden lab",
    description: "van Oudenaarden lab"
  },
  {
    url_mask: "https://ega-archive.org/datasets/#ID",
    name: "EGA dataset",
    description: "European Genome-Phenome Archive Dataset",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://ega-archive.org/studies/#ID",
    name: "EGA Study",
    description: "European Genome-Phenome Archive Study",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/study.cgi?study_id=#ID",
    name: "dbGaP Study",
    description: "dbGAP Study",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://genome.ucsc.edu/cgi-bin/#ID",
    name: "UCSC Genome Browser",
    description: "UCSC Genome Browser",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "http://humphreyslab.com/SingleCell/",
    name: "Kidney Online Transcriptomics",
    description: "Kidney Online Transcriptomics"
  },
  {
    url_mask: "https://zenodo.org/records/#ID https://zenodo.org/record/#ID",
    name: "Zenodo record",
    description: "Zenodo record",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://www.niaid.nih.gov/research/john-tsang-phd",
    name: "John Tsang group",
    description: "John Tsang group"
  },
  {
    url_mask: "https://www.ebi.ac.uk/gxa/sc/experiments/#ID",
    name: "Single Cell Expression Atlas Experiment",
    description: "Single Cell Expression Atlas Experiment",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://www.cellphonedb.org/ http://www.cellphonedb.org/",
    name: "CellphoneDB",
    description: "CellphoneDB"
  },
  {
    url_mask: "https://www.gutcellatlas.org",
    name: "Gut Cell Survey",
    description: "Gut Cell Survey"
  },
  {
    url_mask: "https://developmental.cellatlas.io/#ID",
    name: "Human Cell Atlas Developmental",
    description: "Human Cell Atlas Developmental",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://singlecell.broadinstitute.org/single_cell/study/#ID",
    name: "BroadInstitute Single-Cell Portal",
    description: "BroadInstitute Single-Cell Portal",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "http://www.teichlab.org/",
    name: "Teichmann lab",
    description: "Teichmann lab"
  },
  {
    url_mask: "https://www.kramannlab.com/",
    name: "Kramann lab",
    description: "Kramann lab"
  },
  {
    url_mask: "https://www.sanger.ac.uk/project/#ID",
    name: "Sanger Institute Project",
    description: "Sanger Institute Project",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "http://www.breastatlas.org/ https://navinlabcode.github.io/HumanBreastCellAtlas.github.io/",
    name: "The Human Breast Cell Atlas",
    description: "The Human Breast Cell Atlas"
  },
  {
    url_mask: "https://figshare.com/articles/dataset/#ID",
    name: "FigShare Dataset",
    description: "FigShare Dataset",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://www.insitubiology.org/",
    name: "Chen Lab",
    description: "Chen Lab"
  },
  {
    url_mask: "https://data.mendeley.com/datasets/#ID",
    name: "Mendeley Data Dataset",
    description: "Mendeley Data Dataset",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://www.covid19cellatlas.org/index.patient.html",
    name: "COVID-19 cell atlas",
    description: "COVID-19 cell atlas"
  },
  {
    url_mask: "https://toliaslab.org/",
    name: "Andreas Tolias lab",
    description: "Andreas Tolias lab"
  },
  {
    url_mask: "https://apps.embl.de/abseqapp/",
    name: "ABseq App",
    description: "A resource of gene and surface protein expression in human bone marrow"
  },
  {
    url_mask: "https://git.embl.de/#ID",
    name: "EMBL GitLab",
    description: "EMBL GitLab",
    id_regexp: "^.+?$"
  },
  {
    url_mask: "https://www.ncbi.nlm.nih.gov/sra/#ID",
    name: "SRA Project",
    description: "SRA Project",
    id_regexp: "^SRP.+?$"
  },
  {
    url_mask: "https://www.ebi.ac.uk/ena/browser/view/#ID",
    name: "ENA Project",
    description: "European Nucleotide Archive",
    id_regexp: "^ERP|PRJEB.+?$"
  },
  {
    url_mask: "https://omg.gs.washington.edu/",
    name: "Ontogeny of Mouse, Graphed",
    description: "Ontogeny of Mouse, Graphed"
  },
  {
    url_mask: "http://dx.doi.org/#ID https://doi.org/#ID",
    name: "DOI",
    description: "DOI",
    id_regexp: "^.+?$"
  }
]

ext_sources.each do |source|
  ExtSource.find_or_create_by!(name: source[:name]) do |es|
    es.url_mask = source[:url_mask]
    es.description = source[:description]
    es.id_regexp = source[:id_regexp]
  end
end