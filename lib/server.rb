#!/usr/bin/ruby

#import gems
require "bundler"
require 'uri'
Bundler.require


#ddp is just an extension of a websocket protocol
class DDP::Server < Faye::WebSocket::Client
  attr_accessor :collections, :onconnect

  #sets up basic server for ddp connections
  def initialize( host, port = 8888, path = "websocket",
                  version = 1, support )
    super("http://#{host}:#{port}/#{path}") #setup websocket connection

    self.init_event_handlers()
    @callbacks = {}
    @collections = {}
    @subs = {}
    @sub_ids = {}
    @version = version
    #setup database info
    @mongo = self.get_db_conn

  end
  #set

  #sets up server connection
  def create_server

  end

  def get(collection, data)

  end

  def put(collection,doc, data)
    db = @mongo[collection]
    #insert into database
    db.insert()
    db[doc] = data

    id = db.findOne()


    self.send({
      msg: 'added',
      collection: collection
      id: id,
      fields: data
      })


  end

  def update(collection, doc, data)
    db = @mongo[collection]
    data.each do |k,v|



    end

   self.send({
      msg: 'changed',
      id: id,
      fields: fields,
      cleared: cleared
      })

  end
  #deletes the specified record from the database and sends the proper response
  #to the client
  def delete(collection, doc)
    db = @mongo[collection]

    id = subs[key].id
    db[key].delete

    self.send({
      msg: 'removed',
      collection: collection,
      id: id
    })

  end

  private

  #connects to the proper database based on the current enviroment
  def get_db_conn
    mongo = nil
    configure :development do
      mongo = Mongo::MongoClient.new('localhost', 27017).db('ddp')
    end
    configure :production do
      mongo = get_remote_connection
    end

    #retun connection
    mongo
  end
  #establishes connection to remote database
  def get_remote_connection
    retun db_connection if db_connection
    db = URI..parse(ENV['MONGOHQ_URl'])
    db_name = db.path.gsub(/^\//, '')
    db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
    db_connection.authenticate(db.user, db.password) unless db.user.nil?
    db_connection
    #check incoming message
  end

  #data has beeen added to the server's datastore
  def send_added(collection, id, fields)

    self.send({
      msg: 'added'
      collection: collection,
      id: id,
      fields: fields
      })
  end

  def send_changed(name, id, changed, deleted)

    self.send({
      msg: 'changed',
      id: id,
      fields: fields,
      cleared: cleared
      })
  end


  #sends an array of id's which have sent their initial batch of data
  def send_ready(subs)
    self.send({
      msg: 'ready',
      subs: subs
      })
  end





  #sends the given response as json
  def send data
    self.send(data.to_json)
  end

  def init_event_handlers
    self.onopen = lambda {self.create_server}

    #handle incoming messages from the client
    self.onmessage = lambda do |event|

      data = JSON.parse(event.data)

      if data.has_key? 'msg'

        case data['msg']

        when 'connect'
          #handle incoming connecttion and crossreference with version numbers

          #if successfull send session message

          #else send 'failed' message with new version number

        #inserts a new subscription to be tracked by the server
        when 'sub'
          s_id = data['id']
          s_name = data['name']
          s_params = data['params']

          s_params.each {|k,v| @subs[s_name][s_id][k] = v}

          #update data in id tracker
          @sub_ids[s_id] = s_name

        when 'unsub'
          s_id = data['id']
          s_name = @sub_ids[s_id]

          @subs[s_name].delete

          #send unsub ack in response
          self.send({msg: 'unsub', id: s_id })



        end






      end

      #no message go die


  end


end