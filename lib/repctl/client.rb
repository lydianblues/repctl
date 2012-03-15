#
# This module is intended to be used on the client side to connect to
# the repctl webserver.  It is not part of repctl itself, as it is not
# 'required' by any file in the repctl source code.
#
require 'net/http'

module Repctl
  module Client

    USER = 'admin'
    PASSWORD = 'secret'

    def repl_status(host, opts = {})
      components = { 
        :host => host,
        :path => "/status",
        :port => opts[:port] || 9393, # 7250
      }
      uri = URI::HTTP.build(components)
      do_get(uri)
    end

    def switch_master(host, master, slaves, opts = {})
      master = master.to_s
      slaves = slaves.reduce("") { |list, slave| list + " " + slave.to_s}
      body = "switch[master]=#{master}&switch[slaves]=#{slaves}"
      components = { 
        :host => host,
        :path => "/switch_master",
        :port => opts[:port] || 9393, # 7250
      }
      uri = URI::HTTP.build(components)
      do_post(uri, body)
    end

    def add_slave(host, master, slave, opts = {})
      master = master.to_s
      slave = slave.to_s
      body = "add_slave[master]=#{master}&add_slave[slaves]=#{slave}"
      if opts[:sync]
        body += "&add_slave[sync]=sync"
      end
      components = { 
        :host => host,
        :path => "/add_slave",
        :port => opts[:port] || 9393, # 7250
      }
      uri = URI::HTTP.build(components)
      do_post(uri, body)
    end

    def remove_slave(host, slave, opts = {})
      slave = slave.to_s
      body = "remove_slave[slave]=#{slave}"
      components = { 
        :host => host,
        :path => "/remove_slave",
        :port => opts[:port] || 9393, # 7250
      }
      uri = URI::HTTP.build(components)
      do_post(uri, body)
    end

    def repl_trio(host, master, slaves, opts = {})
      master = master.to_s
      slaves = slaves.reduce("") { |list, slave| list + " " + slave.to_s}
      body = "repl_trio[master]=#{master}&repl_trio[slaves]=#{slaves}"
      components = { 
        :host => host,
        :path => "/repl_trio",
        :port => opts[:port] || 9393, # 7250
      }
      uri = URI::HTTP.build(components)
      do_post(uri, body)
    end

    private

    def do_get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
#     http.use_ssl = true
#     http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      req = Net::HTTP::Get.new(uri.request_uri)
      req.basic_auth(USER, PASSWORD)
      req['Accept'] = 'text/plain'
      response = http.request(req)
      if response.is_a?(Net::HTTPOK)
        response.body
      else
        "Repctl::Client#do_get: #{response.message}"
      end
    end

    def do_post(uri, body)
      http = Net::HTTP.new(uri.host, uri.port)
      #http.use_ssl = true
      #http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      req = Net::HTTP::Post.new(uri.request_uri)
      req.basic_auth(USER, PASSWORD)
      req['Accept'] = 'text/plain'
      req['Content-Type'] = "application/x-www-form-urlencoded"
      req.body = body
      response = http.request(req)
      if response.is_a?(Net::HTTPOK)
        response.body
      else
        "Repctl::Client#do_post: #{response.message}"
      end
    end
  end
end
