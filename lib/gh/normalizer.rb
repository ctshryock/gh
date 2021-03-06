require 'gh'
require 'time'

module GH
  # Public: A Wrapper class that deals with normalizing Github responses.
  class Normalizer < Wrapper
    # Public: Fetches and normalizes a github entity.
    #
    # Returns normalized Response.
    def [](key)
      result = super
      links(result)['self'] ||= { 'href' => full_url(key).to_s } if result.respond_to? :to_hash
      result
    end

    private

    double_dispatch

    def links(hash)
      hash = hash.data if hash.respond_to? :data
      hash["_links"] ||= {}
    end

    def set_link(hash, type, href)
      links(hash)[type] = {"href" => href}
    end

    def modify_response(response)
      response      = response.dup
      response.data = modify response.data
      response
    end

    def modify_hash(hash)
      corrected = {}
      corrected.default_proc = hash.default_proc if hash.default_proc

      hash.each_pair do |key, value|
        key = modify_key(key, value)
        next if modify_url(corrected, key, value)
        next if modify_time(corrected, key, value)
        corrected[key] = modify(value)
      end

      modify_user(corrected)
      corrected
    end

    def modify_time(hash, key, value)
      hash['date'] = Time.at(value).xmlschema if key == 'timestamp'
    end

    def modify_user(hash)
      hash['owner']  ||= hash.delete('user') if hash['created_at']   and hash['user']
      hash['author'] ||= hash.delete('user') if hash['committed_at'] and hash['user']

      hash['committer'] ||= hash['author']    if hash['author']
      hash['author']    ||= hash['committer'] if hash['committer']
    end

    def modify_url(hash, key, value)
      case key
      when "blog"
        set_link(hash, key, value)
      when "url"
        type = Addressable::URI.parse(value).host == api_host.host ? "self" : "html"
        set_link(hash, type, value)
      when /^(.+)_url$/
        set_link(hash, $1, value)
      end
    end

    def modify_key(key, value = nil)
      case key
      when 'gravatar_url'         then 'avatar_url'
      when 'org'                  then 'organization'
      when 'orgs'                 then 'organizations'
      when 'username'             then 'login'
      when 'repo'                 then 'repository'
      when 'repos'                then modify_key('repositories', value)
      when /^repos?_(.*)$/        then "repository_#{$1}"
      when /^(.*)_repo$/          then "#{$1}_repository"
      when /^(.*)_repos$/         then "#{$1}_repositories"
      when 'commit', 'commit_id'  then value =~ /^\w{40}$/ ? 'sha' : key
      when 'comments'             then Numeric === value ? 'comment_count'    : key
      when 'forks'                then Numeric === value ? 'fork_count'       : key
      when 'repositories'         then Numeric === value ? 'repository_count' : key
      when /^(.*)s_count$/        then "#{$1}_count"
      else key
      end
    end
  end
end
