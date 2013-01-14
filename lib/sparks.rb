require 'json'
require 'logger'
require 'net/http/persistent'

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

    def post(room_id, message, type = nil)
      data = {'body' => message}
      data.merge!('type' => type) if type
      json = JSON.generate('message' => data)
      @api.req("/room/#{room_id}/speak", json)
    end

    def speak(message)
      post id, message, 'TextMessage'
    end
    alias_method :say, :speak

    def paste(message)
      post id, message, 'PasteMessage'
    end

    def play(message)
      post id, message, 'SoundMessage'
    end

    def tweet(message)
      post id, message, 'TweetMessage'
    end

    def join
      @api.req("/room/#{id}/join", :post)
    end

    def leave
      @api.req("/room/#{id}/leave", :post)
    end

    def watch
      join # campfire won't let you stream until you join
      @api.stream("/room/#{id}/live") do |message|
        yield message
      end
    end

    def inspect
      %|#<Sparks::Room:#{object_id} @name=#{name.inspect} @id=#{id.inspect}>|
    end

  end

  class Campfire
    attr_reader :logger

    def initialize subdomain, token, opts = {}
      @base   = URI("https://#{subdomain}.campfirenow.com")
      @token  = token
      @logger = opts[:logger] || Logger.new(STDOUT)
      @http   = Net::HTTP::Persistent.new("sparks")

      @http.ca_file = opts[:ca_file] if opts[:ca_file]
    end

    def me
      req("/users/me")
    end

    def room_named(name)
      rooms.find{|r| r.name == name }
    end

    def rooms
      req("/rooms")["rooms"].map do |d|
        Room.new(self, d["name"], d["id"])
      end
    end

    def stream(path)
      # don't allow retries if we've never connected before.
      retries ||= nil

      uri = URI("https://streaming.campfirenow.com") + (path + ".json")
      logger.debug "Ready to stream from #{uri}"

      request = Net::HTTP::Get.new(uri.path)
      request.basic_auth @token, "x"

      @http.request(uri, request) do |response|
        logger.debug "Connected and streaming from #{path}"
        # connected! allow retries.
        retries = 0

        # time to read us some streams
        response.read_body do |chunk|
          # Campfire keepalive pings
          next if chunk == " "

          # One or more JSON payloads per chunk
          chunk.split("\r").each do |message|
            yield JSON.parse(message)
          end
        end
      end
    rescue => e
      # pass through errors if we haven't ever connected
      raise e unless retries

      retries += 1
      logger.error "Error while streaming. Trying again in #{retries * 2}s"
      logger.error "#{e.class}: #{e.message}"
      sleep retries * 2
      retry
    end

    def req(uri, body = nil)
      uri = @base + (uri + ".json") unless uri.is_a?(URI)
      logger.debug "#{body ? 'POST' : 'GET'} #{uri}"

      if body
        request = Net::HTTP::Post.new(uri.path)
        request.body = body unless body == :post
      else
        request = Net::HTTP::Get.new(uri.path)
      end
      request.content_type = "application/json"
      request.basic_auth @token, "x"

      retries ||= 0
      response = @http.request(uri, request)
      response.value   # raises if response is not 2xx
      parse_response(response)

    rescue Net::HTTPRetriableError => e # response was 3xx
      location = URI(response['location'])
      logger.info "Request redirected to #{location}"
      sleep 2
      req(location, body)

    rescue Net::HTTPServerException => e # response was 4xx
      raise "Authorization failed: #{request.class}: #{request.body}"

    rescue Net::HTTPFatalError, Net::HTTP::Persistent::Error => e
      # Retry after 5xx responses or connection errors
      retries += 1
      logger.info "HTTP error: #{e.class}: #{e.message}"
      logger.info "Going to retry request in #{retries * 2}s"
      sleep retries * 2
      retry
    end

  private

    def parse_response(response)
      if response.body.strip.empty?
        true
      else
        JSON.parse(response.body)
      end
    rescue JSON::ParserError
      logger.debug "Couldn't parse #{res.inspect}: #{res.body.inspect}"
      {}
    end

  end
end
