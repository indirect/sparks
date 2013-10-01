require 'logger'
require 'http'
require 'yajl'
require 'base64'

# sparks, a tiny Campfire library

# Usage:
#   c = Sparks.new('subdomain', 'abc123')3
#   r = c.room_named "Room Name"
#   c.say r[:id], "hi there"
#   c.paste r[:id], "class Foo\nend"
#   c.watch(r[:id]) {|message| p message}
class Sparks
  attr_reader :logger

  def initialize subdomain, token, opts = {}
    @base   = URI("https://#{subdomain}.campfirenow.com")
    @token  = token
    @logger = opts[:logger] || Logger.new(STDOUT)
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

    response = HTTP.with_headers(:authorization => authorization).stream.get(uri.to_s)

    # connected! allow retries.
    retries = 0

    logger.debug "Connected and streaming from room #{id}"

    # Set up a Yajl stream parser
    parser = Yajl::Parser.new(:symbolize_keys => true)
    parser.on_parse_complete = -> hash { yield hash }

    # Feed chunks into the stream parser
    response.body do |chunk|
      # Campfire keepalive pings
      next if chunk == " "
      parser << chunk
    end
  rescue Yajl::ParseError,          # Bad JSON in the response
      SystemCallError,              # All Errno errors
      SocketError                  # Errors from socket operations
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

    request = HTTP.with({
      :content_type => "application/json",
      :authorization => authorization
    }).stream

    retries ||= 0

    response = if body
      options = {}
      options.merge!({:body => body}) unless body == :post

      request.post(uri.to_s, options)
    else
      request.get(uri.to_s)
    end

    parse_response(response.body)
  rescue SystemCallError           # All Errno errors
    # Retry if something goes wrong
    retries += 1
    logger.info "Request failed: #{e.class}: #{e.message}"
    logger.info "Going to retry request in #{retries * 2}s"
    sleep retries * 2
    retry
  end

private

  def authorization
    "Basic: #{Base64.encode64([@token, 'x'].join(':'))}".strip
  end

  def parse_response(response)
    if response.strip.empty?
      true
    else
      Yajl::Parser.parse(response, :symbolize_keys => true)
    end
  rescue Yajl::ParseError
    logger.debug "Couldn't parse #{response.inspect}"
    {}
  end

end
