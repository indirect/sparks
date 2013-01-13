require 'uri'
require 'json'
require 'net/https'
require 'logger'

# sparks, a tiny Campfire library

# Usage:
#   c = Sparks::Campfire.new('subdomain', 'abc123')
#   r = c.room_named "Room Name"
#   r.say "hi there"
#   r.paste "class Foo\nend"
module Sparks
  class Room
    attr_reader :name, :id

    def initialize api, name, id
      @api  = api
      @name = name
      @id   = id
    end

    def inspect
      %|#<Sparks::Room:#{object_id} @name=#{name.inspect} @id=#{id.inspect}>|
    end

    def method_missing method, *args, &block
      if @api.respond_to? method
        args.unshift(@id)
        @api.send method, *args, &block
      end
    end
  end

  class Campfire
    attr_reader :logger

    def initialize subdomain, token, opts = {}
      @token   = token
      @pass    = 'x'
      @ca_file = opts[:ca_file]
      @http    = http_for("https://#{subdomain}.campfirenow.com")
      @stream  = http_for("https://streaming.campfirenow.com")
      @logger  = Logger.new(STDOUT)
    end

    def me
      req("/users/me.json")
    end

    def room_named(name)
      r = room_data.find{|r| r["name"] == name }
      r ? Room.new(self, name, r["id"]) : nil
    end

    def rooms
      room_data.map{|d| Room.new(self, d["name"], d["id"]) }
    end

    def room_data
      req("/rooms.json")["rooms"]
    end

    def post(room_id, message, type = nil)
      data = {'body' => message}
      data.merge!('type' => type) if type
      json = JSON.generate('message' => data)
      req("/room/#{room_id}/speak.json", json)
    end

  private

    def http_for(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = @ca_file
      http.ca_file ||= File.expand_path("../rapidssl.crt", __FILE__)
      http
    end

    def req(path, json = nil)
      res = @http.start do |http|
        verb = json ? Net::HTTP::Post : Net::HTTP::Get
        req = verb.new path
        req['Content-Type'] = 'application/json'
        req.basic_auth @token, @pass
        res = json ? http.request(req, json) : http.request(req)
      end
      JSON.parse(res.body)
    rescue JSON::ParserError
      logger.info "Couldn't parse response: #{res.body}"
      {}
    end

  end
end
