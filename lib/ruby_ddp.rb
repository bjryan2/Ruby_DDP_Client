#!usr/bin/env/ruby

#import gems
require "bundler"
Bundler.require

#ddp is just an extension of a websocket protocol
class DDP::Client < Faye::WebSocket::Client
  attr_accessor :collections, :onconnect

  def initialize(host, port = 8888, path = "websocket")
    super("http://#{host}:#{port}/#{path}") #setup websocket connection
    @callbacks = {}
    @next_id = 0
    @collections = {}
  end

  #on connect send the connection message
  def connect
    dosend msg: :connect
  end

  #sends the following request
  def call(method, params = [], &blk)
    id = self.next_id()
    self.dosend(mgs: 'method', id: id, method: method, params: params)
    @callbacks[id] = blk
  end

  private
    def next_id
      (@next_id +=1).to_s
    end

    def dosend data
      self.send(data.to_json)
    end

    def init_event_handlers

      self.onopen = lamda {self.connect()}

      self.onmessage = lambda do |event|
        data = JSON.parse(event.data)

        if data.has_key? 'msg'

          case(data['msg'])
          when 'connected'
            self.onconnect.call event

          #collections
          when 'data'
            if data.has_key? 'collection'
              c_name = data['collection']
              c_id = data['c_id']
              @collections[c_name] ||= {}
              @collections[c_name][c_id] ||={}


              if data.has_key? 'set'
                data['set'].each {|k,v| @collections[c_name][c_id][k] = v}
              end

              if data.has_key? 'unset'
                data['unset'].each {|k| @collections[c_name][c_id].delete key}
              end

              elsif data.has_key 'subs'
                data['subs'].each {|id| cs.call if @callbacks[id]}
            end

            when 'result'
              cb = @callbacks[data['id']]
              cb.call(data['error'], data['result']) if cb
          end #case

        end # msg?

        self.onclose = lambda {|e|}
      end #message handler
    end #init_event_handlrers
end #class





