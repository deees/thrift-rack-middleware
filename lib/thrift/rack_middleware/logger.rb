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

        def log_processing_time(hook_path, rpc_method, &block)
          time = Benchmark.realtime &block
          @logger.info "Completed #{hook_path}##{rpc_method} in #{time_to_readable(time)}"
        end

        def log_error(error, request)
          @logger.error "Error processing thrift request"
          request.body.rewind
          @logger.error "  request body: '#{request.body.read}'"

          @logger.error error
          @logger.error error.backtrace.join("\n\t")

          raise error # reraise the error
        end

        def log_method_name(hook_path, rpc_method)
          @logger.info "Called #{hook_path}##{rpc_method}"
        end

        private

        def time_to_readable(time)
          time >= 1 ? "#{time.round(3)}s" : "#{(time * 1000).round}ms"
        end
      end
    end
  end
end
