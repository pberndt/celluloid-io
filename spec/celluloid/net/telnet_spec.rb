require 'celluloid/net/telnet'
require_relative 'echo_server'

Telnet = Celluloid::Net::Telnet

class MyActor
  include Celluloid::IO

  def initialize(port)
    @telnet = Telnet.new('Host'=>'localhost', 'Port'=>port, 'Telnetmode'=>false)
    wait_for_prompt
  end

  finalizer :on_shutdown

  def on_shutdown
    @telnet.close
  end

  def inc_counter
    puts "Incrementing counter"
    @counter += 1
  end

  def evented_telnet?
    @telnet.sock.evented?
  end

  def wait_for_prompt
    @telnet.waitfor(/^dumb server \$ \z/)
  end

  def command(cmd, options = {})
    options['String'] = cmd
    options['Match'] = /^dumb server \$ \z/ unless options.include?('Match')
    @telnet.cmd(options)
  end

#  def test_evented
#    @counter = 0
#    every(1) { inc_counter }
#    before = @counter
#    puts "calling cmd"
#    command('sleep 2')
#    puts "cmd returned"
#    # the counter should have incremented while waiting for the prompt
#    after = @counter
#    after != before
#  end

  def test_evented_io(sleep, timer=nil, timeout=nil)
    @counter = 0
    every(timer) { inc_counter } if timer
    before = @counter
    begin
      puts "calling cmd"
      start_time = Time.now
      command("sleep #{sleep}", timeout ? {'Timeout'=>timeout} : {})
      puts "cmd returned"
      raise "cmd returned instead of timing out" if timeout && timeout < sleep
      raise "cmd returned too soon" if Time.now - start_time < sleep
    rescue TimeoutError
      puts "cmd timed out"
      raise "unexpected timeout" unless timeout && timeout < sleep
      raise "cmd timed out too soon" if Time.now - start_time < timeout
    end
    # the counter should have incremented while waiting for the prompt
    if @counter == before && timer && timer < [sleep, timeout].min
      raise "did not receive timer callbacks while waiting for the prompt"
    end
  end
end


describe Telnet do
  before(:all) do
    PORT = 47728
    @server = EchoServer.new('localhost', PORT)
  end

  before(:each) do
    @actor = MyActor.new(PORT)
  end

  after(:each) do
    @actor.terminate
    @actor = nil
  end
  after(:all) do
    @server.terminate
    @server = nil
  end

  it "telnet.sock reports to be evented" do
    @actor.evented_telnet?.should be_true
  end

  it "parses command output" do
    @actor.command('echo foo').should match(/^foo$/)
  end

  it "waits for command" do
    @actor.test_evented_io(1)
  end

  it "receives callbacks while waiting" do
    @actor.test_evented_io(2, 1)
  end

  it "receives callbacks while waiting with timeout" do
    @actor.test_evented_io(2, 1, 3)
  end

  it "properly times out waiting" do
    @actor.test_evented_io(3, 1, 2)
  end
end
