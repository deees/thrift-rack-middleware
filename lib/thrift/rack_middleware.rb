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
      set_logger(env)
      request = ::Rack::Request.new(env)
      # Need to add in more logging about the thrift object that was sent in if possible.
      request.logger.info "/rpc_api called"
      if request.post? && request.path == hook_path
        output = StringIO.new
        transport = IOStreamTransport.new(request.body, output)
        protocol = @protocol_factory.get_protocol(transport)
        @processor.process(protocol, protocol)

        output.rewind
        response = Rack::Response.new(output)
        response["Content-Type"] = "application/x-thrift"
        response.finish
      else
        @app.call(env)
      end
    end

    def set_logger(env)
      env['rack.logger'] = if @logger
                             @logger
                           elsif defined?(Rails) && Rails.logger
                             Rails.logger
                           else
                             Logger.new(STDOUT)
                           end
    end
  end
end
