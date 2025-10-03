class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.requires_ontology_link?
    true
  end
end
