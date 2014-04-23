require 'sinatra/base'
require 'haml'
require 'redis'
require 'csv'
require 'json'
require_relative 'models/order.rb'

Dir[File.join(Dir.pwd, 'core_ext', '*.rb')].each { |l| require l }

module Bottleneck
  class Server < Sinatra::Base
    configure do
      $REDIS = Redis.new(path: '/tmp/redis.sock', db: 2)
    end

    helpers do
      def date
        day = (1000 * 60 * 60 * 24)
        now = Time.now

        today = Time.local(now.year, now.month, now.day, 0, 0, 0).to_ms

        {:today => today, :tomorrow => today + day}
      end

      def config
        JSON.parse(File.open("#{Dir.pwd}/products.json").read)
      end
    end

    get '/' do
      from = params['from'] || 0
      to   = params['to']   || Time.now.to_ms
      
      @range = {:from => Time.at(from.to_f / 1000).strftime('%Y-%m-%d'),
                :to =>   Time.at(to.to_f   / 1000).strftime('%Y-%m-%d')}
      @orders = Bottleneck::Order.range(from, to).reverse
      @orders.map! do |e|
        e.merge(config[e['ean']] || {'price' => 1.5})
      end

      @products = Hash.new(0)
      @orders.each do |e|
        @products[e['ean']] += 1
      end

      @overview = []
      @products.keys.each do |k|
        hash = {'ean' => k,
                'count' => @products[k] || 0}
        hash.merge!(config[k] || {'price' => 1.5})
        @overview << hash
      end

      haml :overview
    end

    post '/' do
      ean = params[:ean]
      if ean.is_num?
        time = Time.now.to_ms
        Bottleneck::Order.create(time, ean)
        200 # Created
      else
        400 # Bad Request
      end
    end

    post '/date' do
      range = params[:range]
      from = Time.strptime(range[:from], '%Y-%m-%d').to_ms.to_s
      to   = Time.strptime(range[:to], '%Y-%m-%d').to_ms.to_s
      redirect "/?from=#{from}&to=#{to}"
    end

    get '/chart' do
      headers "Content-Type" => "application/json"

      json = {}
      json['cols'] = [
        {"id" => "", "label" => "Product", "pattern" => "", "type" => "string"},
        {"id" => "", "label" =>  "Count", "pattern" =>  "", "type" => "number"}
      ]

      orders = Bottleneck::Order.range(0, Time.now.to_ms)
      products = Hash.new(0)
      orders.each do |e|
        products[e['ean']] += 1
      end

      rows = []
      products.each do |k, v|
        hash = {'c' => [
          {'v' => (config[k] || {'name' => k})['name'],
           'f' => nil},
          {'v' => v,
           'f' => nil}
        ]} 
        rows << hash
      end

      json['rows'] = rows      
      json.to_json
    end

    get '/export' do
      filename = "bottleneck-#{Time.now.strftime('%F')}"
      headers "Content-Disposition" => "attachment;filename=#{filename}.csv",
              "Content-Type" => "application/octet-stream"


      orders = Bottleneck::Order.range(0,Time.now.to_ms)
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

