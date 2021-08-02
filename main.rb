#!/usr/bin/env ruby

# Variables become preferences in the app:
#
#  <xbar.var>string(VAR_NOTION_TOKEN="hoge"): Notion Token.</xbar.var>
#  <xbar.var>string(VAR_NOTION_TODO_DATABASE_ID="foo"): Target Database ID.</xbar.var>

require 'net/http'
require 'json'
require 'time'

class Notion
  QUERY_DATABASE_ENDPOINT = 'https://api.notion.com/v1/databases/%<DATABASE_ID>s/query'

  def initialize(token)
    @base_headers = {
      'Authorization': "Bearer #{token}",
      'Notion-Version': '2021-05-13',
      'Content-Type': 'application/json'
    }
  end

  # ref: https://developers.notion.com/reference/post-database-query
  def query_database(database_id, params)
    uri = URI.parse(QUERY_DATABASE_ENDPOINT % { DATABASE_ID: database_id })
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === 'https'

    response = http.post(uri.path, params.to_json, @base_headers)
    JSON.parse(response.body)
  end

  def self.query_database(token, database_id, params)
    new(token).query_database(database_id, params)
  end
end


class Formatter
  def self.format(res, debug: false)
    contents = [].tap do |a|
      res['results'].each do |content|
        a << {
          name: content.dig('properties', 'Action Item', 'title').first.dig('plain_text'),
          category: content.dig('properties', 'カテゴリ', 'select', 'name'),
          status: content.dig('properties', 'Status', 'select', 'name'),
          now: content.dig('properties', 'now', 'checkbox')
        }
      end
    end

    p contents if debug

    [].tap do |a|
      contents.each_with_index do |content, i|
        if i == 0 && content[:now]
          a << ":zap:#{content[:name]}"
          a << '---'
          a << ':one:今やってる'
          a << "#{content[:name]}"
        elsif i == 1
          a << '---'
          a << ':two:次にやるリスト'
          a << "--#{content[:name]}"
        else
          a << "--#{content[:name]}"
        end
      end
    end
  end
end

DEBUG = ENV.fetch('DEBUG', false)
TOKEN = ENV['VAR_NOTION_TOKEN']
DATABASE_ID = ENV['VAR_NOTION_TODO_DATABASE_ID']

params = {
  filter: {
    and: [
      {
          property: 'Status',
          select: {
            does_not_equal: 'Done'
          }
      },
      {
          property: '実施日',
          date: {
            on_or_before: Time.now.iso8601
          }
      },
    ]
  },
  sorts: [
    {
	    "property": "now",
	    "direction": "descending"
	  },
    {
	    "property": "Alert",
	    "direction": "descending"
	  },
    {
	    "property": "Priority",
	    "direction": "ascending"
	  },
  ]
}
res = Notion.query_database(TOKEN, DATABASE_ID, params)
Formatter.format(res, debug: DEBUG).each do |val|
  puts val
end

