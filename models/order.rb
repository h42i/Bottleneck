module Bottleneck
  class Order
    def self.range(from, to)
      orders = $REDIS.zrangebyscore('orders', from, to)
      orders.map do |e|
        p = e.split(':')
        {'time' => p[0].to_i, 'ean' => p[1]}
      end
    end

    def self.create(time, ean)
      $REDIS.zadd('orders', time, "#{time}:#{ean}")
    end
  end
end
