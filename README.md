# thrift-rack-middleware

A simple rack middleware that can intercept HTTP thrift requests.

This is useful when used in combination with a pooled application server like passenger.
It is not an easy task to have thrift directly target worker processes that application servers like passenger manage.

Accessing the handler applications via thrift this was may not be the fastest, but it is one of the easier ways to get started.

## Usage

If you want to add this middleware to a Rails application, add the following to your config/application.rb

    handler = ThriftHandler.new
    processor = MyThrift::Processor.new(handler)
    config.middleware.insert_before Rails::Rack::Metal, Thrift::RackMiddleware,
                                                        processor: processor,
                                                        hook_path: '/thrift_rpc',
                                                        protocol_factory: Thrift::BinaryProtocolAcceleratedFactory.new

### Defaults

* `hook_path` defaults to `'/rpc_api'`
* `protocol_factory` defaults to `Thrift::BinaryProtocolFactory.new`
* `logger` see logging section below

#### Logging
You can optionally pass in a custom logger instance. If your application is a
Rails application, Rails.logger will automatically be used. If your application
is a Rack application, rack logger will automatically be used. Otherwise, logging
will be directed to STDOUT

## Future features

* Add a way to pass in a lambda or other means to insert authentication logic into the middleware.
* Add PIDs to the logs

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
