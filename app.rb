require 'sinatra/base'
require 'haml'
require 'redis'
require 'csv'
require_relative 'models/order.rb'

Dir[File.join(Dir.pwd, 'core_ext', '*.rb')].each { |l| require l }

module Bottleneck
  class Server < Sinatra::Base
    configure do
      $REDIS = Redis.new(db: 3)
    end

    helpers do
      def todayMidnight
        now = Time.now
        Time.local(now.year, now.month, now.day, 0, 0, 0).to_ms
      end
      def tomorrowMidnight
        todayMidnight + (1000 * 60 * 60 * 24)
      end
    end

    get '/' do
      @config = JSON.parse(File.open("#{Dir.pwd}/products.json").read)

      from = params['from'] || 0
      to   = params['to']   || Time.now.to_ms
      @orders = Bottleneck::Order.in_range(from, to).reverse
      @orders.map! do |e|
        e.merge(@config[e['ean']] || {'price' => 1.5})
      end

      @products = Hash.new(0)
      @orders.each do |e|
        @products[e['ean']] += 1
      end

      @overview = []
      @products.keys.each do |k|
        hash = {'ean' => k,
                'count' => @products[k] || 0}
        hash.merge!(@config[k] || {'price' => 1.5})
        @overview << hash
      end

      haml :overview
    end

    post '/' do
      ean = params[:ean]
      if ean.is_num?
        time = Time.now.to_ms
        Bottleneck::Order.create(time, ean)
        #200 # OK
        redirect '/'
      else
        400 # Bad Request
      end
    end

    get '/export' do
      filename = "bottleneck-#{Time.now.strftime('%F')}"
      headers "Content-Disposition" => "attachment;filename=#{filename}.csv",
              "Content-Type" => "application/octet-stream"


      orders = Bottleneck::Order.all
      csv = CSV.generate do |c|
        c << ['timestamp', 'ean']
        for order in orders
          c << [order['time'], order['ean']]
        end
      end

      csv
    end

    get '/test' do
      haml :test
    end
  end
end

