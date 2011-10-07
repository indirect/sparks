require 'uri'
require 'json'
require 'net/https'

# sparks, a tiny Campfire library

# Usage:
#   c = Sparks::Campfire.new('subdomain', 'abc123')
#   r = c.room_named "Room Name"
#   r.say "hi there"
#   r.paste "class Foo\nend"
module Sparks
  class Room
    attr_accessor :id

    def initialize api, name, id
      @api  = api
      @name = name
      @id   = id
    end

    def method_missing method, *args, &block
      if @api.respond_to? method
        args.unshift(@id)
        @api.send method, *args, &block
      end
    end
  end

  class Campfire
    attr_reader :uri, :token, :pass

    def initialize subdomain, token, opts = {}
      @uri   = URI.parse("https://#{subdomain}.campfirenow.com")
      @token = token
      @pass  = 'x'

      @http             = Net::HTTP.new(uri.host, uri.port)
      @http.use_ssl     = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      campfire_ca_certs = File.expand_path("../rapidssl.crt", __FILE__)
      @http.ca_file     = opts[:ca_file] || campfire_ca_certs
    end

    def room_named name
      r = rooms.find{|r| r["name"] == name }
      r ? Room.new(self, name, r["id"]) : nil
    end

    def rooms
      @http.start do |http|
        req = Net::HTTP::Get.new "/rooms.json"
        req['Content-Type'] = 'application/json'
        req.basic_auth token, pass
        begin
          JSON.parse(http.request(req).body)["rooms"]
        rescue JSON::ParserError
          {}
        end
      end
    end

    def post room_id, message, type = nil
      data = {'body' => message}
      data.merge!('type' => type) if type
      json = JSON.generate('message' => data)

      @http.start do |http|
        req = Net::HTTP::Post.new "/room/#{room_id}/speak.json"
        req['Content-Type'] = 'application/json'
        req.basic_auth token, pass
        http.request(req, json)
      end
    end

    def speak room_id, message
      post room_id, message, 'TextMessage'
    end
    alias_method :say, :speak

    def paste room_id, message
      post room_id, message, 'PasteMessage'
    end

    def play room_id, message
      post room_id, message, 'SoundMessage'
    end
    
    def tweet room_id, message
      post room_id, message, 'TweetMessage'
    end

    def join room_id
      @http.start do |http|
        req = Net::HTTP::Post.new "/room/#{room_id}/join.xml"
        req.basic_auth token, pass
        http.request(req)
      end
    end

    def watch room_id
      uri = URI.parse('https://streaming.campfirenow.com')

      x             = Net::HTTP.new(uri.host, uri.port)
      x.use_ssl     = true
      x.verify_mode = OpenSSL::SSL::VERIFY_NONE

      x.start do |http|
        req = Net::HTTP::Get.new "/room/#{room_id}/live.json"
        req.basic_auth token, pass
        http.request(req) do |res|
          res.read_body do |chunk|
            unless chunk.strip.empty?
              chunk.split("\r").each do |message|
                yield JSON.parse(message)
              end
            end
          end
        end
      end
    end

  end
end
