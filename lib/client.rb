#!usr/bin/env/ruby

#import gems
require "bundler"
Bundler.require

#ddp is just an extension of a websocket protocol
class DDP::Client < Faye::WebSocket::Client
  attr_accessor :collections, :connect_m

  #sets up basic server for ddp connections
  def initialize( host, port = 8888, path = "websocket",
                  version, support )
    super("http://#{host}:#{port}/#{path}") #setup websocket connection

    #handler for incoming respones from the server
    self.init_handlers()

    @sub_callbacks = {}
    @collections = {}
    @sub_ids = {}
    @version = version
    @last_suc_version = nil
    @session = nil
    @curr_id = 0
    @support = support
  end

  #sends a method call
  def call_method(method, params = [], &blk)
    id = self.next_id()
    self.send(msg: 'method', id: id, method: method, params: params)
    @sub_callbacks[id] = blk
  end

  #subscripe to the data 'name' on the server
  #this function will assign an arbitrary id to the subscription so that
  #it may be tracked by the client
  def subscribe(name, params, &blk)
    id = self.next_id()
    self.send(msg: 'sub', id: id, name: name, params: params)

    @sub_ids[name] = id
    @sub_callbacks[id] = blk
  end

  #client unsibscribes from the specified subscription
  def unsubscribe(name)
    id = @sub_ids[name]
    self.send(msg: 'unsub', id: id)
  end

  private

  #sends connection message to server
  def connect(version = @version)

    #send initial connection request
    self.send(msg: :connect, version: @version, support: @support)

    #handle incoming response form the server
    self.onmessage = lambda do |event|

      res = JSON.parse(event.data)

      if res.has_key? 'session'
        #connection is successful - update session and record version
        @session = res['session'].to_s
        @last_suc_version = @version

      #if the connection fails the suggested version should be retrieved
      #from the response and the connection should be made
      else #there was a failed connection
        sug_version = res['version']
        #retry the send request with the version specified by the server
        self.connect(sug_version)

      end
    end
  end

  #updates and returns the next available ID number
  def next_id
    (@curr_id +=1).to_s
  end

  def send data
    self.send(data.to_json)
  end

  #handlers for server sents
  def init_handlers
    #begin the client session by attempting to connect to the server
    self.onopen = lamda { self.connect() }

    self.onmessage = lambda do |event|

      data = JSON.parse(event.data)

      if data.has_key? 'msg'

      case(data['msg'])
        when 'connected'
          self.connect_m.send_method event

          #inserts the given data into the client datastore
        when 'added'
          if data.has_key? 'collection'
            c_name = data['collection']
            c_id = data['id']
            @collections[c_name] ||= {}
            data['params'].each { |k,v| @collections[c_name][c_id][k] = v }
          end

          #update the given data in the clients datastore
        when 'changed'
           if data.has_key 'collection'
              c_name = data['collection']
              c_id = data['id']
              c_fields = data['fields']
              to_clear = data['cleared']

              #clear out fields specified at 'cleared'
              to_clear.each { |f| @collections[c_name][c_id][f].delete f }
              #insert/udpdate new data
              c_fields.each { |k,v| @collections[c_name][c_id][k] = v }
           end

          #remove the given data from the client's datastore
        when 'removed'
          if data.has_key 'collection'
            c_name = data['collection']
            c_id = data['id']
            @collections[c_name][c_id] = nil
          end

        #adds the document *before* that whose id is specified in the id
        #field of addedBefore
        when 'addedBefore'
          if data.has_key? 'collection'
            c_name = data['collection']
            c_id = data['id']
            before = data['before']

            @collections[c_name] ||= {}
            #adds before if non-null
            if before
              data['params'].each { |k,v| @collections[c_name][c_id-1][k] = v }
            else
              data['params'].each { |k,v| @collections[c_name][c_id][k] = v }
            end
          end

        when 'movedBefore'
          if data.has_key? 'collection'
            c_name = data['collection']
            c_id = data['id']
            before = data['before']

            @collections[c_name] ||= {}
            #adds before if non-null
            if before
              data['params'].each { |k,v| @collections[c_name][c_id-1][k] = v }
            else
              data['params'].each { |k,v| @collections[c_name][c_id][k] = v }
            end
          end

        when 'ready'
          puts "Server acks READY"

      end #case
      end # msg?

      self.on(:close) = lambda {|e| puts "Connection Closed"}
      end #message handler
  end #init_handlrers
end



