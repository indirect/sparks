require 'logger'
require 'net/http/persistent'
require 'yajl'

# sparks, a tiny Campfire library

# Usage:
#   c = Sparks.new('subdomain', 'abc123')
#   r = c.room "Room Name"
#   c.say r["id"], "hi there"
#   c.paste r["id"], "class Foo\nend"
class Sparks
  attr_reader :logger

  def initialize subdomain, token, opts = {}
    @base   = URI("https://#{subdomain}.campfirenow.com")
    @token  = token
    @logger = opts[:logger] || Logger.new(STDOUT)
    @http   = Net::HTTP::Persistent.new("sparks")
    @http.ca_file = opts[:ca_file] if opts[:ca_file]
    @http.verify_mode = opts[:verify_mode] if opts[:verify_mode]
    @rooms ||= {}
  end

  def me
    user("me")
  end

  def user(id)
    req("/users/#{id}")[:user]
  end

  def room_named(name)
    req("/rooms")[:rooms].find{|r| r[:name] == name }
  end

  def room(id)
    @rooms[id] ||= begin
      req("/room/#{id.to_s}")[:room]
    end
  end

  def join(id)
    req("/room/#{id}/join", :post)
  end

  def leave(id)
    req("/room/#{id}/leave", :post)
  end

  def speak(id, message, type = 'TextMessage')
    data = {'body' => message, 'type' => type}
    json = Yajl::Encoder.encode('message' => data)
    req("/room/#{id}/speak", json)
  end
  alias_method :say, :speak

  def paste(id, message)
    speak id, message, 'PasteMessage'
  end

  def play(id, message)
    speak id, message, 'SoundMessage'
  end

  def tweet(id, message)
    speak id, message, 'TweetMessage'
  end

  def watch(id)
    # campfire won't let you stream until you've joined the room
    join(id)

    # don't allow retries if we've never connected before.
    retries ||= nil

    uri = URI("https://streaming.campfirenow.com") + "/room/#{id}/live.json"
    logger.debug "Ready to stream from #{uri}"

    request = Net::HTTP::Get.new(uri.path)
    request.basic_auth @token, "x"

    @http.request(uri, request) do |response|
      logger.debug "Connected and streaming from room #{id}"
      # connected! allow retries.
      retries = 0

      # Set up a Yajl stream parser
      parser = Yajl::Parser.new(:symbolize_keys => true)
      parser.on_parse_complete = -> hash { yield hash }

      # Feed chunks into the stream parser
      response.read_body do |chunk|
        # Campfire keepalive pings
        next if chunk == " "
        parser << chunk
      end
    end
  rescue Yajl::ParseError,          # Bad JSON in the response
      SystemCallError,              # All Errno errors
      SocketError,                  # Errors from socket operations
      Net::HTTP::Persistent::Error, # Timeout, SSL, or connection error
      Net::HTTPBadResponse,         # response wasn't 2xx
      Net::HTTPHeaderSyntaxError,   # response header issue
      Net::ProtocolError => e       # not http
    # pass through errors if we haven't ever connected
    raise e unless retries
    # if we connected at least once, try, try, again
    retries += 1
    logger.error "#{e.class}: #{e.message}"
    logger.error "Trying to stream again in #{retries * 2}s"
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
    msg = "Authorization failed: HTTP #{response.code}"
    msg << ": " << request.body if request.body && !request.body.empty?
    raise msg

  rescue SystemCallError,           # All Errno errors
      Net::HTTP::Persistent::Error, # Timeout, SSL, or connection error
      Net::HTTPBadResponse,         # response wasn't 2xx
      Net::HTTPHeaderSyntaxError,   # response header issue
      Net::ProtocolError => e       # not http
    # Retry if something goes wrong
    retries += 1
    logger.info "Request failed: #{e.class}: #{e.message}"
    logger.info "Going to retry request in #{retries * 2}s"
    sleep retries * 2
    retry
  end

private

  def parse_response(response)
    if response.body.strip.empty?
      true
    else
      Yajl::Parser.parse(response.body, :symbolize_keys => true)
    end
  rescue Yajl::ParseError
    logger.debug "Couldn't parse #{res.inspect}: #{res.body.inspect}"
    {}
  end

end
