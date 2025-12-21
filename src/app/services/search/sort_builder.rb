module Search
  class SortBuilder
    def initialize(sort_param, is_search)
      @sort_param = sort_param
      @is_search = is_search
    end

    def build
      case @sort_param
      when "cells_desc" then [{ cell_count: "desc" }]
      when "cells_asc" then [{ cell_count: "asc" }]
      else
        @is_search ? ["_score", { cell_count: "desc" }] : [{ cell_count: "desc" }]
      end
    end
  end
end
