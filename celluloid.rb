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

    @user, @pass = Netrc.read["loxone"]
    data = "#{@user}:#{@pass}" 

		digest = OpenSSL::Digest.new('sha1')
		hmac = OpenSSL::HMAC.digest(digest, key, data).unpack("H*").first

		@ws_client.text("authenticate/#{hmac}")

#    body = http.get("/data/LoxAPP3.json").body
#    binding.pry

    @ws_client.text("jdev/sps/enablebinstatusupdate")

		#@ws_client.text("jdev/sys/getkey")
  end

  def register_filter(filter)
    @filters ||= []
    filters << filter
  end

	def http
		conn ||= Faraday.new(:url => 'http://192.168.11.10') do |faraday|
  		faraday.request  :url_encoded             # form-encode POST params
 			faraday.response :logger                  # log requests to STDOUT
  		faraday.response :json, :content_type => /\bjson$/
      faraday.basic_auth(@user, @pass)
			faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
		end
	end


  class Control
    attr_reader :name, :type, :uuid
    def initialize(control_hash)
      @name = control_hash.fetch("name")
      @type = control_hash.fetch("type")
      @uuid = control_hash.fetch("uuidAction")
    end
  end

  def control(uuid)
    Control.new(controls[uuid])
  end

  def controls
    @controls ||= http.get("/data/LoxAPP3.json").body["controls"]
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
      begin
        puts "Name: #{control(uuid(msg)).name}"
      rescue
      end
      puts "DATA: #{decodefloat64(data_value_state(msg))}"
    end

    event = Event.new(:value_state, uuid(msg), decodefloat64(data_value_state(msg)))
    filters.each { |f| f.run(event) }
  end

  def text_state(msg)
    if msg.is_a? Array
      puts "UUID: #{uuid(msg)}"
      puts "DATA: #{data_text_state(msg)}"
    end
  end

  # When WebSocket is closed
  def on_close(code, reason)
    puts "WebSocket connection closed: #{code.inspect}, #{reason.inspect}"
  end

  def uuid(msg)
    x = msg.map { |e| "%02x" % e }
    [decode32(x[0..3].join), decode16(x[4..5].join), decode16(x[6..7].join), x[8..15].join].join("-")
  end

  def data_value_state(msg)
    msg.map { |e| "%02x" % e }[16..-1].to_a.join
  end

  def data_text_state(msg)
    msg[36..-1].pack("U*")
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
  module Effects
    class Base
      attr_reader :number_of_leds, :leds_pin
      
      def initialize(number_of_leds, leds_pin)
        @number_of_leds = number_of_leds
        @leds_pin = leds_pin

        # right strip -> pin 18 -> 109 leds
        # left strip  -> pin 17 ->  98 leds
      end

      private

      
      def ws
        @ws ||= Ws2812::Basic.new(number_of_leds, leds_pin, 10, channel: leds_pin%2)
      end

      def set_pixel(pixel, color)
        ws.open
        ws[pixel] = Ws2812::Color.new(*color)
        #ws.close
      end
    end

    class SingleColor < Base
      attr_accessor :color
      
      def initialize(number_of_leds, leds_pin, color)
        super(number_of_leds, leds_pin)
        @color = Ws2812::Color.new(*color)
      end

      def run
        ws.open
        colorize
        ws.show
        sleep(0.01)
        #ws.close
      end

      private

      def colorize
        ws[(0...number_of_leds)] = color 
      end

    end


    class SimpleFire < Base
      attr_accessor :timer

      def initialize(timer)
        @timer = timer
      end

      def run
        r = 255
        g = r-40;
        b = 40;

        number_of_leds.times do |led|
          flicker = rand(150)
          r1 = r-flicker
          g1 = g-flicker
          b1 = b-flicker

          g1=0 if(g1<0) 
          r1=0 if(r1<0) 
          b1=0 if(b1<0) 

          
          set_pixel(led, [r1, g1, b1])

        end

        ws.show

        timer.wait(1)

      end   
    end
  end

end



Stairlights::Effects::SingleColor.new( 98, 19, [rand(255), rand(255), rand(255)]).run
Stairlights::Effects::SingleColor.new(109, 18, [rand(255), rand(255), rand(255)]).run


#Stairlights::Effects::SingleColor.new( 50, ARGV[0].to_i, [ARGV[1].to_i, ARGV[2].to_i, ARGV[3].to_i]).run

#(0..40).each do |i|
#	puts "#{i} -> #{Stairlights::Effects::SingleColor.new( 98, i, [0, 0, 0]).run rescue "x"}"
#end

#m = WSConnection.new('ws://192.168.11.10/ws/rfc6455')
#filter = EventFilter.new(:value_state, "0d2956bb-02a8-1e74-ffffda868d47d75b") do |event|
#  if event.value > 1.0
#    Stairlights::Effects::SimpleFire.new.run
#  else
#    Stairlights::Effects::SingleColor.new(109, 18, [0, 0, 0]).run
#    Stairlights::Effects::SingleColor.new( 98, 17, [0, 0, 0]).run
#  end
#end
#m.register_filter(filter)
#
#while true; sleep; end
#
