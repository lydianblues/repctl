require 'sinatra'
require 'repctl'

include Repctl::Config
include Repctl::Commands
include Repctl::Servers
include Repctl::Helpers
include Repctl::Color

def time
  start = Time.now
  yield
  Time.now - start
end

helpers do
  def img(name)
    "<img src='images/#{ name}' alt='#{ name}' />"
  end

  def master_slave_params(params)
    param_error = false
    @error_message = nil
    if params.nil? || params["master"] == "" || params["master"].nil? ||
      params["slaves"] == nil || params["slaves"] == ""
      @error_message = "parameters missing"
    else
      begin
        master = params["master"].to_i
        slaves = params["slaves"].split("\s").map(&:to_i)
      rescue Exception => e
        @error_message = "invalid format for parameters"
      else
        if master == 0 || slaves.include?(0)
          @error_message = "0 can not be an instance"
        elsif slaves.include?(master)
          @error_message = "master can not also be a slave"
        elsif slaves.empty?
          @error_message = "no slaves are specified"
        end
      end
    end
    [@error_message, master, slaves]
  end
end
      
get '/' do
  erb :main
end

# curl deimos:9393/switch_master --header "Accept: text/plain" \
#   -d switch[slaves]="2 1 4" -d switch[master]=3
post '/switch_master' do
  @message, master, slaves = master_slave_params(params["switch"])
  if @message
    @success = false
  else
    secs = time do
      do_switch_master(master, slaves)
    end
    @message = "Switch to master #{master.to_s} processed in #{secs} secs."
    @success = true
  end
  if request.accept == ['text/plain']
    if @success
      "#{@message}\n".colorize(:green)
    else
      "#{@message}\n".colorize(:red)
    end
  else
    erb :operation_complete, :layout => !request.xhr?
  end
end

# curl deimos:9393/add_slave --header "Accept: text/plain" \
#   -d add_slave[master]=1 -d add_slave[slaves]=3 -d add_slave[sync]=sync
post '/add_slave' do
  @message, master, slaves = master_slave_params(params["add_slave"])
  options = {}
  if params["add_slave"] && params["add_slave"]["sync"] == "sync"
    options[:sync] = true
  end
  unless slaves && slaves[0]
    @message = "You need to specify a slave"
  end
  if @message
    @success = false
  else
    slave = slaves[0]
    secs = time do
      do_add_slave(master, slave, options)
    end
    @message = "Added slave #{slave} to master #{master} in #{secs} secs."
    @success = true
  end
  if request.accept == ['text/plain']
    if @success
      "#{@message}\n".colorize(:green)
    else
      "#{@message}\n".colorize(:red)
    end
  else
    erb :operation_complete, :layout => !request.xhr?
  end
end

# curl deimos:9393/remove_slave --header "Accept: text/plain" \
#   -d remove_slave[slave]=3
post '/remove_slave' do
  slave = params["remove_slave"]["slave"]
  secs = time do
    do_remove_slave(slave)
  end
  @message = "Removed slave #{slave} in #{secs} secs."
  @success = true
  if request.accept == ['text/plain']
    if @success
      "#{@message}\n".colorize(:green)
    else
      "#{@message}\n".colorize(:red)
    end
  else
    erb :operation_complete, :layout => !request.xhr?
  end
end

# curl deimos:9393/repl_trio --header "Accept: text/plain" \
#   -d repl_trio[master]=1 -d repl_trio[slaves]="2 3"
post '/repl_trio' do
  @message, master, slaves = master_slave_params(params["repl_trio"])
  if @message
    @success = false
  else
    secs = time do
      do_repl_trio(master, slaves[0], slaves[1])
    end
    @message = "Create replication trio with master #{master} and " +
      "slaves #{slaves[0]} and #{slaves[1]} in #{secs} secs."
    @success = true
  end
  if request.accept == ['text/plain']
    if @success
      "#{@message}\n".colorize(:green)
    else
      "#{@message}\n".colorize(:red)
    end
  else
    erb :operation_complete, :layout => !request.xhr?
  end
end

# curl deimos:9393/status --header "Accept: text/plain"
get '/status' do
  if request.accept == ['text/plain']
    formatted_status.join("\n") + "\n"
  else
    @timestamp = Time.now.strftime("%I:%M:%S %p")
    @status_array = repl_status
    erb :status , :layout => !request.xhr?
  end
end


