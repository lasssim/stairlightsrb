#!/usr/local/bin/ruby

require 'bundler/setup'

Bundler.require


n = 24 # num leds
ws = Ws2812::Basic.new(n, 18) # +n+ leds at pin 18, using defaults
ws.open

ws[(0...n)] = Ws2812::Color.new(0xff, 0, 0)

ws.show


