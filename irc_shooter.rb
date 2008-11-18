=begin
Shooter
  <http://gist.github.com/25886>

  Harry Vangberg <http://trueaffection.net>
  Simon Rozet    <http://purl.org/net/sr/>

EXAMPLE

  IRC.shoot('irc://irc.freenode.net:6667/integrity', :as => "IntegrityBot") do |channel|
    channel.say "check me out! http://gist.github.com/25886"
  end

LICENSE

  WTFPL <http://sam.zoy.org/wtfpl/>
=end
require "rubygems"
require "addressable/uri"
require "socket"

class Shooter
  def self.shoot(uri, options={}, &block)
    raise ArgumentError unless block_given?

    uri = Addressable::URI.parse(uri)
    irc = new(uri.host, uri.port, options.delete(:as)) do |irc|
      irc.join(uri.path[1..-1], &block)
    end
  end

  def initialize(server, port, nick)
    raise ArgumentError unless block_given?

    @socket = TCPSocket.open(server, port)
    @socket.puts "NICK #{nick}"
    @socket.puts "USER #{nick} #{nick} #{nick} :#{nick}"
    yield self
    @socket.puts "QUIT"
    @socket.gets until @socket.eof?
  end

  def join(channel)
    raise ArgumentError unless block_given?

    @channel = "##{channel}"
    @socket.puts "JOIN #{@channel}"
    yield self
    @socket.puts "PART #{@channel}"
  end

  def say(message)
    return unless @channel
    @socket.puts "PRIVMSG #{@channel} :#{message}"
  end
end

if $0 == __FILE__
  begin
    require 'spec'
  rescue LoadError
    abort "No test for you :-("
  end

  describe "Shooter" do
    def create_shooter(&block)
      @shooter ||= Shooter.new("irc.freenode.net", 6667, "john", &block || lambda {})
    end

    setup do
      @socket = mock("socket", :puts => "", :eof? => true, :gets => "")
      TCPSocket.stub!(:open).and_return(@socket)
    end

    it "should exists" do
      Shooter.should be_an_instance_of Class
    end

    describe "When using Shooter.shoot" do
      def do_shoot(&block)
        Shooter.shoot("irc://irc.freenode.net:6667/foo", :as => "john", &block || lambda {})
      end

      it "raises ArgumentError if no block given" do
        lambda { do_shoot(nil) }.should raise_error(ArgumentError)
      end

      it "creates a new shooter using URI and :as option" do
        Shooter.should_receive(:new).with("irc.freenode.net", 6667, "john")
        do_shoot
      end

      it "join channel using URI's path" do
        create_shooter.should_receive(:join).with("foo")
        Shooter.stub!(:new).and_yield(create_shooter)
        do_shoot
      end

      it "passes given block to join" do
        pending
      end
    end

    describe "When initializing" do
      it "raises ArgumentError if no block given" do
        lambda do
          create_shooter(nil)
        end.should raise_error(ArgumentError)
      end

      it "opens a TCPSocket to the given host on the given port" do
        TCPSocket.should_receive(:open).with("irc.freenode.net", 6667).and_return(@socket)
        create_shooter
      end

      it "sets its nick" do
        @socket.should_receive(:puts).with("NICK john")
        create_shooter
      end

      it "yields itself" do
        create_shooter { |shooter| shooter.should respond_to(:join) }
      end

      it "quits" do
        @socket.should_receive(:puts).with("QUIT")
        create_shooter
      end
    end

    describe "When joining a channel" do
      def do_join(&block)
        create_shooter { |shooter| shooter.join('foo', &block || lambda {}) }
      end

      it "raises ArgumentError if no block given" do
        lambda do
          do_join(nil)
        end.should raise_error(ArgumentError)
      end

      it "joins the given channel" do
        @socket.should_receive(:puts).with("JOIN #foo")
        do_join
      end

      it "yields itself" do
        do_join { |channel| channel.should respond_to(:say) }
      end

      it "parts the given channel" do
        @socket.should_receive(:puts).with("PART #foo")
        do_join
      end
    end

    describe "When saying something" do
      it "should say the given message in the channel" do
        @socket.should_receive(:puts).with("PRIVMSG #foo :bar")
        create_shooter { |shooter| shooter.join("foo") { |channel| channel.say "bar" } }
      end

      it "should stfu and return nil if not joined to a channel" do
        @socket.should_not_receive(:puts).with("PRIVMSG #foo :bar")
        create_shooter { |shooter| shooter.say("bar").should be_nil }
      end
    end
  end
end
