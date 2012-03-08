require 'sinatra'
require 'repctl'

include Repctl::Config
include Repctl::Commands
include Repctl::Servers
include Repctl::Utils
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
    @message = "Switch master processed in #{secs} secs."
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

post '/repl_trio' do
  @message, master, slaves = master_slave_params(params["repl_trio"])
  if @message
    @success = false
  else
    secs = time do
      sleep 1
    end
    @message = "Create replication trio with master #{master} and slaves #{slaves} in #{secs} secs."
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


