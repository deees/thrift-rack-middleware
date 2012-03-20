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

require 'spec_helper'
require 'thrift/rack_middleware'

  include Thrift

  describe RackMiddleware do
    before(:each) do
      @processor = mock("Processor")
      @factory = mock("ProtocolFactory")
      @mock_app = mock("AnotherRackApp")
      @middleware = RackMiddleware.new(@mock_app, :processor => @processor, :protocol_factory => @factory)
    end

    it "should call next rack application in the stack if request was not a post and not pointed to the hook_path" do
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "not_the_hook_path"}
      @mock_app.should_receive(:call).with(env)
      Rack::Response.should_not_receive(:new)
      @middleware.call(env)
    end

    it "should serve using application/x-thrift" do
      env = {"REQUEST_METHOD" => "POST", "PATH_INFO" => "/rpc_api"}
      IOStreamTransport.stub!(:new)
      @factory.stub!(:get_protocol)
      @processor.stub!(:process)
      response = mock("RackResponse")
      response.should_receive(:[]=).with("Content-Type", "application/x-thrift")
      response.should_receive(:finish)
      Rack::Response.should_receive(:new).and_return(response)
      @middleware.call(env)
    end

    it "should use the IOStreamTransport" do
      body = mock("body")
      env = {"REQUEST_METHOD" => "POST", "PATH_INFO" => "/rpc_api", "rack.input" => body}
      output = mock("output")
      output.should_receive(:rewind)
      StringIO.should_receive(:new).and_return(output)
      protocol = mock("protocol")
      transport = mock("transport")
      IOStreamTransport.should_receive(:new).with(body, output).and_return(transport)
      @factory.should_receive(:get_protocol).with(transport).and_return(protocol)
      @processor.should_receive(:process).with(protocol, protocol)
      response = mock("RackResponse")
      response.stub!(:[]=)
      response.should_receive(:finish)
      Rack::Response.should_receive(:new).and_return(response)
      @middleware.call(env)
    end

    it "should have appropriate defaults for hook_path and protocol_factory" do
      mock_factory = mock("BinaryProtocolFactory")
      mock_proc = mock("Processor")
      BinaryProtocolFactory.should_receive(:new).and_return(mock_factory)
      rack_middleware = RackMiddleware.new(@mock_app, :processor => mock_proc)
      rack_middleware.hook_path.should == "/rpc_api"
    end

    it "should understand :hook_path, :processor and :protocol_factory" do
      mock_proc = mock("Processor")
      mock_factory = mock("ProtocolFactory")

      rack_middleware = RackMiddleware.new(@mock_app, :processor => mock_proc,
                                                      :protocol_factory => mock_factory,
                                                      :hook_path => "/thrift_api")

      rack_middleware.processor.should == mock_proc
      rack_middleware.protocol_factory.should == mock_factory
      rack_middleware.hook_path.should == "/thrift_api"
    end

    it "should raise ArgumentError if no processor was specified" do
      lambda { RackMiddleware.new(@mock_app) }.should raise_error(ArgumentError)
    end
  end

