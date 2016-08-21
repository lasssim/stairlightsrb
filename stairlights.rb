#!/usr/local/bin/ruby

require 'bundler/setup'

Bundler.require

n = 24 # num leds
ws = Ws2812::Basic.new(n, 18) # +n+ leds at pin 18, using defaults
ws.open

# first pixel set to red
ws[0] = Ws2812::Color.new(0xff, 0, 0)

# all other set to green
ws[(1...n)] = Ws2812::Color.new(0, 0xff, 0xff)

# second pixel set to blue, via individual components
ws.set(1, 0, 0, 0xff)

# show it
ws.show


