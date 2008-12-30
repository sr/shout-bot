=begin
ShoutBot
  Ridiculously simple library to quickly say something on IRC
  <http://github.com/sr/shout-bot>

EXAMPLE

  ShoutBot.shout('irc://irc.freenode.net:6667/github', :as => "ShoutBot") do |channel|
    channel.say "check me out! http://github.com/sr/shout-bot"
  end

LICENSE

             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                     Version 2, December 2004

  Copyright (C) 2008 Simon Rozet <http://purl.org/net/sr/>
  Copyright (C) 2008 Harry Vangberg <http://trueaffection.net>

  Everyone is permitted to copy and distribute verbatim or modified
  copies of this license document, and changing it is allowed as long
  as the name is changed.

             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
    TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

   0. You just DO WHAT THE FUCK YOU WANT TO.
=end

require "rubygems"
require "addressable/uri"
require "socket"

class ShoutBot
  def self.shout(uri, options={}, &block)
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
    sleep 1
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
    require "spec"
  rescue LoadError
    abort "No test for you :-("
  end

  describe "ShoutBot" do
    def create_shouter(&block)
      @shouter ||= ShoutBot.new("irc.freenode.net", 6667, "john", &block || lambda {})
    end

    setup do
      @socket = mock("socket", :puts => "", :eof? => true, :gets => "")
      TCPSocket.stub!(:open).and_return(@socket)
    end

    it "should exists" do
      ShoutBot.should be_an_instance_of Class
    end

    describe "When using Shouter.shout" do
      def do_shout(&block)
        ShoutBot.shout("irc://irc.freenode.net:6667/foo", :as => "john", &block || lambda {})
      end

      it "raises ArgumentError if no block given" do
        lambda { do_shout(nil) }.should raise_error(ArgumentError)
      end

      it "creates a new shouter using URI and :as option" do
        ShoutBot.should_receive(:new).with("irc.freenode.net", 6667, "john")
        do_shout
      end

      it "join channel using URI's path" do
        create_shouter.should_receive(:join).with("foo")
        ShoutBot.stub!(:new).and_yield(create_shouter)
        do_shout
      end

      it "passes given block to join" do
        pending
      end
    end

    describe "When initializing" do
      it "raises ArgumentError if no block given" do
        lambda do
          create_shouter(nil)
        end.should raise_error(ArgumentError)
      end

      it "opens a TCPSocket to the given host on the given port" do
        TCPSocket.should_receive(:open).with("irc.freenode.net", 6667).and_return(@socket)
        create_shouter
      end

      it "sets its nick" do
        @socket.should_receive(:puts).with("NICK john")
        create_shouter
      end

      it "yields itself" do
        create_shouter { |shouter| shouter.should respond_to(:join) }
      end

      it "quits" do
        @socket.should_receive(:puts).with("QUIT")
        create_shouter
      end
    end

    describe "When joining a channel" do
      def do_join(&block)
        create_shouter { |shouter| shouter.join('foo', &block || lambda {}) }
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
        create_shouter { |shouter| shouter.join("foo") { |channel| channel.say "bar" } }
      end

      it "should stfu and return nil if not joined to a channel" do
        @socket.should_not_receive(:puts).with("PRIVMSG #foo :bar")
        create_shouter { |shouter| shouter.say("bar").should be_nil }
      end
    end
  end
end
