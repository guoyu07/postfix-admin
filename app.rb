class App < Sinatra::Base
  set :views, settings.root + '/app/views'
  config = YAML.load_file('conf/config.yml')

  set :database_host => config['database']['host']
  set :database_name => config['database']['name']
  set :database_user => config['database']['user']
  set :database_password => config['database']['password']

  set :admin_name => config['auth']['username']
  set :admin_password => config['auth']['password']

  DB = Sequel.connect(:adapter => 'mysql2', :host => settings.database_host, :database => settings.database_name,
                      :user => settings.database_user, :password => settings.database_password)
  Sequel::Model.plugin :json_serializer

  set :locales, File.join(File.dirname(__FILE__), 'i18n/en.yml', 'i18n/de.yml')
  register Sinatra::R18n

  class Forwarding < Sequel::Model
    plugin :json_serializer
  end

  class User < Sequel::Model
    plugin :json_serializer
  end


  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [settings.admin_name, settings.admin_password]
    end
  end

  before do
    session[:locale] = params[:locale] if params[:locale]
    protected! unless request.path_info == "/"
  end

# ROOT
  get '/' do
    erb :index
  end

# Page for FORWARDINGS
  get '/configure_forwardings', :provides => 'html' do
    erb :forwardings
  end

# Page for MAILBOXES
  get '/configure_mailboxes', :provides => 'html' do
    erb :mailboxes
  end


# Services for FORWARDINGS
  get '/forwardings', :provides => 'json' do
    return {:forwardings => Forwarding.all()}.to_json
  end

  post '/forwardings', :provides => 'json' do
    bodyParams = JSON.parse(request.body.read)
    source = params["source"].nil? ? bodyParams["source"] : params["source"]
    destination = params["destination"].nil? ? bodyParams["destination"] : params["destination"]

    DB[:forwardings].insert(:source => source, :destination => destination)
  end

  get '/forwardings/:email', :provides => 'json' do |email|
    Forwarding.filter(:source => email).first.to_json(:root => true)
  end

  post '/forwardings/:email', :provides => 'json' do |email|
    bodyParams = JSON.parse(request.body.read)
    destination = params["destination"].nil? ? bodyParams["destination"] : params["destination"]
    DB[:forwardings].filter(:source => email).update(:destination => destination)
  end

  delete '/forwardings/:email', :provides => 'json' do |email|
    DB[:forwardings].filter(:source => email).delete
  end

# Services for MAILBOXES
  get '/users', :provides => 'json' do
    return {:users => User.all()}.to_json
  end

  post '/users', :provides => 'json' do
    bodyParams = JSON.parse(request.body.read)
    email = params["email"].nil? ? bodyParams["email"] : params["email"]
    old_password = params["old_password"].nil? ? bodyParams["old_password"] : params["old_password"]
    password = params["password"].nil? ? bodyParams["password"] : params["password"]
    password_confirmation = params["password_confirmation"].nil? ? bodyParams["password_confirmation"] : params["password_confirmation"]

    if password.eql?(password_confirmation) then
      if DB[:users].filter(:email => email).empty?
        DB[:users].insert(:email => email, :password => :Encrypt.sql_function(password))
      else
        DB[:users].filter(:email => user).update(:password => :Encrypt.sql_function(password)) unless DB[:users].filter(:email => email, :password => :Encrypt.sql_function(password)).empty?
      end
    end
  end

  get '/users/:user', :provides => 'json' do |user|
    User.filter(:email => user).first.to_json(:root => true)
  end

  post '/users/:user', :provides => 'json' do |user|
    bodyParams = JSON.parse(request.body.read)
    password = params["password"].nil? ? bodyParams["password"] : params["password"]
    password_confirmation = params["password_confirmation"].nil? ? bodyParams["password_confirmation"] : params["password_confirmation"]
    if password.eql?(password_confirmation) then
      DB[:users].filter(:email => user).update(:password => :Encrypt.sql_function(password))
    end
  end

  delete '/users/:user', :provides => 'json' do |user|
    DB[:users].filter(:email => user).delete
  end
end
