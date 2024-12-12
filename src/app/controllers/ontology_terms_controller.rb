class OntologyTermsController < ApplicationController
  def show
    @term = OntologyTerm.find_by(id: params[:id])
    render turbo_stream: turbo_stream.update("tag-modal-content", partial: "ontology_terms/modal_content")
  end
end
