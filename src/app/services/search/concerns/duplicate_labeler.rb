# frozen_string_literal: true

module Search
  module Concerns
    module DuplicateLabeler
      private

      def label_duplicates(items, &identifier_extractor)
        name_groups = items.group_by { |item| extract_name(item).to_s.downcase }
        duplicate_names = name_groups.select { |_, group| group.size > 1 }.keys

        return items if duplicate_names.empty?

        items.map do |item|
          name = extract_name(item)

          if duplicate_names.include?(name.to_s.downcase)
            identifier = identifier_extractor.call(item)
            ontology_prefix = extract_ontology_prefix(identifier)

            if ontology_prefix
              update_item_name(item, "#{name} (#{ontology_prefix})")
            else
              item
            end
          else
            item
          end
        end
      end

      def extract_ontology_prefix(identifier)
        return nil unless identifier

        identifier.split(":").first
      end

      def extract_name(item)
        item.is_a?(Hash) ? item[:name] : item.name
      end

      def update_item_name(item, new_name)
        if item.is_a?(Hash)
          item.merge(name: new_name)
        else
          Facets::TreeNode.new(
            id: item.id,
            name: new_name,
            count: item.count,
            has_children: item.has_children,
            has_selected_children: item.has_selected_children
          )
        end
      end
    end
  end
end
