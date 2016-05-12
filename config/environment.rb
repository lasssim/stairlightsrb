require 'rubygems'
require 'bundler'

env = ENV['RACK_ENV'] || :development
Bundler.require(:default, env) 

$:.unshift(File.expand_path('../../lib', __FILE__))

require ::File.expand_path("../environments/#{env}",  __FILE__)

require 'canvas'
