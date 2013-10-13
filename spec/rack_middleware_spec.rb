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
      @processor = double("Processor", :process => nil)
      @factory = double("ProtocolFactory", :get_protocol => double)
      @mock_app = double("AnotherRackApp")
      @logger = double("Logger").as_null_object
      @middleware = RackMiddleware.new(@mock_app, :processor => @processor, :protocol_factory => @factory, :logger => @logger)
    end

    it "should call next rack application in the stack if request was not a post and not pointed to the hook_path" do
      env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "not_the_hook_path"}
      @mock_app.should_receive(:call).with(env)
      Rack::Response.should_not_receive(:new)
      @middleware.call(env)
    end

    context "thrift request" do
      let(:request_body) { StringIO.new 'test_method' }
      let(:env) { {"REQUEST_METHOD" => "POST", "PATH_INFO" => "/rpc_api", "rack.input" => request_body} }

      it "should serve using application/x-thrift" do
        response = double("RackResponse")
        response.should_receive(:[]=).with("Content-Type", "application/x-thrift")
        response.should_receive(:finish)
        Rack::Response.should_receive(:new).and_return(response)
        @middleware.call(env)
      end

      it "should use the IOStreamTransport" do
        protocol = double("protocol")
        transport = double("transport")
        IOStreamTransport.should_receive(:new).with(request_body, instance_of(StringIO)).and_return(transport)
        @factory.should_receive(:get_protocol).with(transport).and_return(protocol)
        @processor.should_receive(:process).with(protocol, protocol)
        response = double("RackResponse")
        response.stub(:[]=)
        response.should_receive(:finish)
        Rack::Response.should_receive(:new).and_return(response)
        @middleware.call(env)
      end

      it "should log incoming method names" do
        @logger.should_receive(:info).twice.with(/test_method/)
        @middleware.call(env)
      end

      it "should log failures" do
        error = RuntimeError.new('Fake Error')
        @processor.stub(:process).and_raise(error)
        @logger.should_receive(:error).with(error)
        expect { @middleware.call(env) }.to raise_error(error)
      end
    end

    it "should have appropriate defaults for hook_path and protocol_factory" do
      mock_factory = double("BinaryProtocolFactory")
      mock_proc = double("Processor")
      BinaryProtocolFactory.should_receive(:new).and_return(mock_factory)
      rack_middleware = RackMiddleware.new(@mock_app, :processor => mock_proc)
      rack_middleware.hook_path.should == "/rpc_api"
    end

    it "should understand :hook_path, :processor and :protocol_factory" do
      mock_proc = double("Processor")
      mock_factory = double("ProtocolFactory")

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

