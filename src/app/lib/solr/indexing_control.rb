module Solr
  module IndexingControl
    def self.without_indexing
      original_session = Sunspot.session

      Sunspot.session = Sunspot::Rails::StubSessionProxy.new(original_session)

      yield
    ensure
      Sunspot.session = original_session
    end
  end
end
