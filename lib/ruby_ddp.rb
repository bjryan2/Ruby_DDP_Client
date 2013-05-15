#!usr/bin/env/ruby

#import gems
require "bundler"
Bundler.require

#ddp is just an extension of a websocket protocol
class DDP::Client < Faye::WebSocket::Client
  attr_accessor :collections, :onconnect

  #sets up basic server for ddp connections
  def initialize( host, port = 8888, path = "websocket",
                  version = self.version, support )
    super("http://#{host}:#{port}/#{path}") #setup websocket connection

    self.init_event_handlers()

    @callbacks = {}
    @collections = {}
    @subs = {}
    @version = version
    @session = nil
    @curr_id = 0
    @support = support

  end

  #sends connection message to server
  def connect
    self.send({
          msg: :connect,
          version: @version,
          support: @support
        })

    #handle incoming response form the server
    self.onmessage = lambda do |event|

      res = JSON.parse(event.data)

      if res.has_key? 'session'
        #connection is successful - update session and record version
        @session = res['session'].to_s
        @@last_suc_version = @version

      else #there was a failed connection
        @version = res['version']
        #retry the send request with the version specified by the server
        self.send({
          msg: :connect
          version: @version,
          support: @support
          })
      end

    end
  end

  #sends a method call
  def call(method, params = [], &blk)
    id = self.next_id()
    self.send(msg: 'method', id: id, method: method, params: params)
    @callbacks[id] = blk
  end

  #subscripe to the data 'name' on the server
  #this function will assign an arbitrary id to the subscription so that
  #it may be tracked by the client
  def subscribe(name, params, &blk)
    id = self.next_id()
    self.send({msg: 'sub', id: id, name: name, params: params})

    @subs[name] = id
    @callbacks[id] = blk
  end

  #client unsibscribes from the specified subscription
  def unsubscribe(name)
    id = @subs[name]

    self.send(msg: 'unsub', id: id)
  end

  private
    #updates and returns the next available ID number
    def next_id
      (@curr_id +=1).to_s
    end

    def send data
      self.send(data.to_json)
    end

    #handlers for sever sents
    def init_event_handlers
      #begin the client session by attempting to connect to the server
      self.onopen = lamda {self.connect()}

      self.onmessage = lambda do |event|

        data = JSON.parse(event.data)

        if data.has_key? 'msg'

          case(data['msg'])

          #successfull connection!
          when 'connected'
            self.connect.call event

          #inserts the given data into the client datastore
          when 'addad'
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
              to_clear.each do |f|
                @collections[c_name][c_id][f].delete f
              end
              #insert/udpdate new data
              c_fields.each do |k,v|
                @collections[c_name][c_id][k] = v
              end

            end

          #remove the given data from the client's datastore
          when 'removed'
            if data.has_key 'collection'
              c_name = data['collection']
              c_id = data['id']
              @collections[c_name][c_id] = nil
            end

          when 'ready'
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

        #there is no message ???

        self.on(:close) = lambda {|e| puts "Connection Closed"}
      end #message handler
    end #init_event_handlrers

end #class





