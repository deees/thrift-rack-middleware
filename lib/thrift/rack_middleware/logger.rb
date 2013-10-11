require "logger"
require "benchmark"

module Thrift
  module Rack
    module Middleware
      class Logger

        def initialize(env)
          @env = env
        end

        def or(logger)
          @logger = logger if logger
          self
        end

        def create!
          return self if @logger

          @logger = if defined?(Rails) && Rails.logger
            Rails.logger
          elsif env.key? "rack.logger"
            env["rack.logger"]
          else
            Logger.new(STDOUT)
          end

          self
        end

        def log_processing_time(rpc_method, &block)
          time = Benchmark.realtime &block
          @logger.info "Total time taken processing RPC request for #{rpc_method}: #{time} seconds"
        end

        def log_error(error, request, output)
          @logger.error "Error processing thrift request"
          @logger.error error
          request.body.rewind
          @logger.error "  request body: #{request.body.read}"
          output.rewind
          @logger.error "  output: #{output.read}"
          raise error # reraise the error
        end

        def log_method_name(rpc_method)
          @logger.info "#{@hook_path} called with method: #{rpc_method}"
        end
      end
    end
  end
end
