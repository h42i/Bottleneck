require 'json'

module Bottleneck
  class Order
    def self.all
      self.in_range(0, -1)
    end

    def self.in_range(from, to)
      $REDIS.zrangebyscore('orders', from, to).map { |e| JSON.parse(e) }
    end

    def self.create(time, ean)
      $REDIS.zadd('orders', time, {:time => time, :ean => ean}.to_json)
    end
  end
end
