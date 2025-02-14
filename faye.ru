require 'faye'
require 'faye/redis'
require 'rack'


bayeux = Faye::RackAdapter.new(
  mount: '/faye',
  timeout: 25,
  engine: {
    type: Faye::Redis,
    host: 'localhost',
    port: 6379,
    database: 0
  }
)

run bayeux
