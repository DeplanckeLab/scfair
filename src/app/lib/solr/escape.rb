module Solr
    module Escape
      def self.escape(string)
        special_chars = %w(+ - && || ! ( ) { } [ ] ^ " ~ * ? : /)
        special_chars.each do |char|
          string = string.gsub(char) { |c| "\\#{c}" }
        end
        string
      end
    end
  end