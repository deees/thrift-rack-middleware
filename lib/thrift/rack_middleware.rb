#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

# A Rack application to be used within a Rails application to provide an API
# access via Thrift. You have to insert it into the MiddlewareStack of Rails
# within a custom initializer and not within the environment, because Thrift
# is not fully loaded at that point.
# 
# Here is a sample of to to use it:
# 
#     ActionController::Dispatcher.middleware.insert_before Rails::Rack::Metal, Thrift::RackMiddleware,
#                                                                               { :processor => YourCustomProcessor.new,
#                                                                                 :hook_path => "/the_path_to_receive_api_calls",
#                                                                                 :protocol_factory => Thrift::BinaryProtocolAcceleratedFactory.new }
# 
# Some benchmarking showed this is much slower then any Thrift solution without
# Rails, but it is still fast enough if you need to integrate your Rails app
# into a Thrift-based infrastructure.
# 
begin
  require 'rack'
  require 'rack/response'
  require 'rack/request'
rescue LoadError => e
  Kernel.warn "[WARNING] The Rack library could not be found. Please install it to use the Thrift::RackMiddleware server part."
end

require "logger"
require "thrift"

module Thrift
  class RackMiddleware
    attr_reader :hook_path, :processor, :protocol_factory

    def initialize(app, options = {})
      @app              = app
      @processor        = options[:processor] || (raise ArgumentError, "You have to specify a processor.")
      @protocol_factory = options[:protocol_factory] || BinaryProtocolFactory.new
      @hook_path        = options[:hook_path] || "/rpc_api"
      @logger           = options[:logger]
    end

    def call(env)
      request = ::Rack::Request.new(env)
      # Need to add in more logging about the thrift object that was sent in if possible.
      if request.post? && request.path == hook_path
        logger = find_logger(env)
        # Try to parse the method called from the request body
        rpc_method_match = request.body.read.match(/(?<method_name>[a-z_0-9]+)/i)
        rpc_method = rpc_method_match ? rpc_method_match[:method_name] : 'UNKNOWN'
        request.body.rewind
        logger.info "#{@hook_path} called with method: #{rpc_method}"
        start_time = Time.now
        output = StringIO.new
        transport = IOStreamTransport.new(request.body, output)
        protocol = @protocol_factory.get_protocol(transport)
        begin
          @processor.process(protocol, protocol)
        rescue
          logger.error "Error processing thrift request"
          logger.error $!
          request.body.rewind
          logger.error "  request body: #{request.body.read}"
          output.rewind
          logger.error "  output: #{output.read}"
          raise $! # reraise the exception
        end

        logger.info "Total time taken processing RPC request for #{rpc_method}: #{Time.now - start_time} seconds"
        output.rewind
        response = ::Rack::Response.new(output)
        response["Content-Type"] = "application/x-thrift"
        response.finish
      else
        @app.call(env)
      end
    end

    def find_logger(env)
      if @logger
        @logger
      elsif defined?(Rails) && Rails.logger
        @logger = Rails.logger
      elsif env.key? "rack.logger"
        env["rack.logger"]
      else
        @logger = Logger.new(STDOUT)
      end
    end
  end
end
