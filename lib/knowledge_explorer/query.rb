# frozen_string_literal: true

module KnowledgeExplorer
  class Query

    def initialize(user = nil, filters = {})
      @user = user
      @filters = filters
    end

    def categories
      SiteSetting.knowledge_explorer_categories.split("|")
    end

    def tags
      SiteSetting.knowledge_explorer_tags.split("|")
    end

    def get

      # query for topics matching selected categories & tags
      tq = TopicQuery.new(@user)
      results = tq.latest_results({:no_definitions => true})
      results = results.left_outer_joins(:tags)
      results = results.where('category_id IN (?)', categories).or(results.where('tags.name IN (?)', tags))

      # filter results by selected tags
      if !@filters[:tags].nil?
        results = results.where('tags.name IN (?)', @filters[:tags])
      end

      # get tag count
      tags = []

      results.each do |topic|
        topic.tags.each do |tag|
          if @filters[:tags]
            active = @filters[:tags].include?(tag.name)
          end
          if tags.none? { |item| item[:id].to_s == tag.name }
            tags << { id: tag.name, count: 1 , active: active || false }
          else
            tag_index = tags.index(tags.find { |item| item[:id].to_s == tag.name })
            tags[tag_index][:count] += 1
          end
        end
      end

      tags = tags.sort_by { |tag| [tag[:active] ? 0 : 1, -tag[:count]] }

      # assemble the object
      topic_query = tq.create_list(:knowledge_explorer, {}, results)

      topic_list = TopicListSerializer.new(topic_query, scope: Guardian.new(@user)).as_json

      { tags: tags, topics: topic_list }
    end
  end
end
