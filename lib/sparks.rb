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

    def speak(message)
      @api.post id, message, 'TextMessage'
    end
    alias_method :say, :speak

    def paste(message)
      @api.post id, message, 'PasteMessage'
    end

    def play(message)
      @api.post id, message, 'SoundMessage'
    end

    def tweet(message)
      @api.post id, message, 'TweetMessage'
    end

    def join
      @api.req("/room/#{id}/join.json")
    end

    def watch
      puts "GONNA JOIN"
      join
      puts "zomg I'm in"
      @api.watch(id){|message| yield message }
    end

    def inspect
      %|#<Sparks::Room:#{object_id} @name=#{name.inspect} @id=#{id.inspect}>|
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
      rooms.find{|r| r.name == name }
    end

    def rooms
      req("/rooms.json")["rooms"].map do |d|
        Room.new(self, d["name"], d["id"])
      end
    end

    def post(room_id, message, type = nil)
      data = {'body' => message}
      data.merge!('type' => type) if type
      json = JSON.generate('message' => data)
      req("/room/#{room_id}/speak.json", json)
    end

    def watch(room_id)
      @streamer.start do |http|
        req = Net::HTTP::Get.new "/room/#{room_id}/live.json"
        req.basic_auth @token, @pass
        http.request(req) do |res|
          res.read_body do |chunk|
            next if chunk.strip.empty?
            chunk.split("\r").each do |message|
              yield JSON.parse(message)
            end
          end
        end
      end
    rescue => e
      puts "gotta retry :("
      raise e
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
