#!/usr/local/bin/ruby

require 'bundler/setup'


Bundler.require
#
#
#class MozWeb
#  include Celluloid
#  include Celluloid::Logger
#
#  def initialize
#    @client = Celluloid::WebSocket::Client.new("ws://192.168.11.10/ws/rfc6455", current_actor)
#    @counter = 0
#		@client.write("adsf")
#  end
#
#  def on_open
#    debug("websocket connection opened")
#  end
#
#  def on_message(data)
#    @counter += 1
#    info("message: #{data.inspect}")
#
#    @client.close if @counter > 5
#  end
#
#  def on_close(code, reason)
#    debug("websocket connection closed: #{code.inspect}, #{reason.inspect}")
#  end
#end
#
#MozWeb.new
#
#sleep
#

require 'celluloid/websocket/client'
require 'json'
require 'openssl'

class WSConnection
  include Celluloid

  attr_accessor :filters

  def initialize(url)
    key = [http.get("/jdev/sys/getkey").body["LL"]["value"]].pack("H*")
    @ws_client = Celluloid::WebSocket::Client.new url, Celluloid::Actor.current
    #key = [JSON.parse(msg)["LL"]["value"]].pack("H*")

    user, pass = Netrc.read["loxone"]
    data = "#{user}:#{pass}" 

		digest = OpenSSL::Digest.new('sha1')
		hmac = OpenSSL::HMAC.digest(digest, key, data).unpack("H*").first

		@ws_client.text("authenticate/#{hmac}")
  
    @ws_client.text("jdev/sps/enablebinstatusupdate")

		#@ws_client.text("jdev/sys/getkey")
  end

  def register_filter(filter)
    @filters ||= []
    filters << filter
  end

	def http
		conn = Faraday.new(:url => 'http://192.168.11.10') do |faraday|
  		faraday.request  :url_encoded             # form-encode POST params
 			faraday.response :logger                  # log requests to STDOUT
  		faraday.response :json, :content_type => /\bjson$/
			faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
		end
	end

	def env
		{	
			"HTTP_SEC_WEBSOCKET_PROTOCOL" => "remotecontrol"
		}
	end

  # When WebSocket is opened, register callbacks
  def on_open
    puts "Websocket connection opened"
  end

  # When raw WebSocket message is received
  def on_message(msg)

    @state ||= :header

    if @state == :header
      @state = [:text, :binary, :value_state, :text_state, :daytimer_state][msg[1]]
    else
      puts 
      puts "State: #{@state}"
      send(@state, msg) if respond_to? @state
      @state = :header
    end
  end

  def value_state(msg)

    if msg.is_a? Array

      puts "UUID: #{uuid(msg)}"
      puts "DATA: #{decodefloat64(data(msg))}"
    end

    event = Event.new(:value_state, uuid(msg), decodefloat64(data(msg)))
    filters.each { |f| f.run(event) }
  end

  # When WebSocket is closed
  def on_close(code, reason)
    puts "WebSocket connection closed: #{code.inspect}, #{reason.inspect}"
  end

  def uuid(msg)
    x = msg.map { |e| "%02x" % e }
    [decode32(x[0..3].join), decode16(x[4..5].join), decode16(x[6..7].join), x[8..15].join].join("-")
  end

  def data(msg)
    msg.map { |e| "%02x" % e }[16..-1].to_a.join
  end

  def decode32(str)
    [str].pack('H*').unpack('N*').pack('V*').unpack('H*')
  end

  def decode16(str)
    [str].pack('H*').unpack('n*').pack('v*').unpack('H*')
  end

  def decodefloat64(str)
    [str].pack('H*').unpack("E").first
  end

end

class Event
  attr_reader :type, :uuid, :value
  def initialize(type, uuid, value)
    @type = type
    @uuid = uuid
    @value = value
  end
end

class EventFilter
  attr_reader :uuid, :message_type, :block
  def initialize(message_type, uuid, &block)
    @message_type = message_type
    @uuid         = uuid
    @block        = block
  end

  def run(event)
    block.call(event) if event.type == message_type and event.uuid == uuid
  end
  
end


module Stairlights
  class SingleColor 
    attr_accessor :color
    attr_reader :number_of_leds, :leds_pin
    
    def initialize(color)
      @color = Ws2812::Color.new(*color)
      @number_of_leds = 24
      @leds_pin = 18
      ws.open
    end

    def run
      colorize
      ws.show
    end

    private

    def ws
      @ws ||= Ws2812::Basic.new(number_of_leds, leds_pin)
    end

    def colorize
      ws[(0...number_of_leds)] = color 
    end

  end

end

m = WSConnection.new('ws://192.168.11.10/ws/rfc6455')
filter = EventFilter.new(:value_state, "0e4ceede-02a2-606f-ffff9837378acad5") do |event|
  ap event
  if event.value == 1.0
    Stairlights::SingleColor.new([0xff, 0xff, 0]).run
  else
    Stairlights::SingleColor.new([0, 0, 0]).run
  end
end
m.register_filter(filter)

while true; sleep; end

