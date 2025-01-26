class MultipleMatchesError < StandardError
  def initialize(search_term)
    super("Multiple matches found for '#{search_term}'")
  end
end
