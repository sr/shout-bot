=begin
ShoutBot
  Ridiculously simple library to quickly say something on IRC
  <http://github.com/sr/shout-bot>

EXAMPLE

  ShoutBot.shout('irc://shoutbot:password@irc.freenode.net:6667/#github') do |channel|
    channel.say "check me out! http://github.com/sr/shout-bot"
  end

LICENSE

             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                     Version 2, December 2004

  Copyright (C) 2008, 2009 Simon Rozet <http://purl.org/net/sr/>
  Copyright (C) 2008, 2009 Harry Vangberg <http://trueaffection.net>

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
  def self.shout(uri, &block)
    raise ArgumentError unless block_given?

    uri = Addressable::URI.parse(uri)
    irc = new(uri.host, uri.port, uri.user, uri.password) do |irc|
      if channel = uri.fragment
        irc.join(channel, &block)
      else
        irc.channel = uri.path[1..-1]
        yield irc
      end
    end
  end

  attr_accessor :channel

  def initialize(server, port, nick, password=nil)
    raise ArgumentError unless block_given?

    @socket = TCPSocket.open(server, port || 6667)
    @socket.puts "PASSWORD #{password}" if password
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

if $0 == __FILE__ || $0 == "-e"
  require "test/unit"
  require "context"
  require "rr"

  class MockSocket
    attr_accessor :in, :out
    def gets() @in.gets end
    def puts(m) @out.puts(m) end
    def eof?() true end
  end

  class ShoutBot
    include Test::Unit::Assertions
  end

  class Test::Unit::TestCase
    include RR::Adapters::TestUnit

    def setup
      @socket, @server = MockSocket.new, MockSocket.new
      @socket.in, @server.out = IO.pipe
      @server.in, @socket.out = IO.pipe

      stub(TCPSocket).open(anything, anything) {@socket}
    end
  end

  class TestShoutBot < Test::Unit::TestCase
    def create_shoutbot(&block)
      ShoutBot.new("irc.freenode.net", 6667, "john", &block || lambda {})
    end

    def create_shoutbot_and_register(&block)
      create_shoutbot &block
      2.times { @server.gets } # NICK + USER
    end

    test "raises error if no block given" do
      assert_raises ArgumentError do
        ShoutBot.new("irc.freenode.net", 6667, "john")
      end
    end

    test "registers to the irc server" do
      create_shoutbot
      assert_equal "NICK john\n", @server.gets
      assert_equal "USER john john john :john\n", @server.gets
    end

    test "sends password if specified" do
      # hey, retarded test!
      ShoutBot.new("irc.freenode.net", 6667, "john", "malbec") {@socket}
      assert_equal "PASSWORD malbec\n", @server.gets
    end
    
    test "falls back to port 6667 if not specified" do
      # talk about retarded test
      mock(TCPSocket).open("irc.freenode.net", 6667) {@socket}
      ShoutBot.new("irc.freenode.net", nil, "john") {}
    end

    test "quits after doing its job" do
      create_shoutbot_and_register {}
      assert_equal "QUIT\n", @server.gets
    end

    test "raises error if no block is given to join" do
      create_shoutbot do |bot|
        assert_raises(ArgumentError) {bot.join "integrity"}
      end
    end

    test "joins channel" do
      create_shoutbot_and_register do |bot|
        bot.join("integrity") {}
      end
      assert_equal "JOIN #integrity\n", @server.gets
    end

    test "doesn't do anything until receiving RPL_MYINFO / 004" do
      # pending
    end

    test "joins channel and says something" do
      create_shoutbot_and_register do |bot|
        bot.join "integrity" do |c|
          c.say "foo bar!"
        end
      end
      @server.gets # JOIN
      assert_equal "PRIVMSG #integrity :foo bar!\n", @server.gets
    end

    test "sends private message to user" do
      create_shoutbot_and_register do |bot|
        bot.channel = "sr"
        bot.say "Look Ma, new tests!"
      end
      assert_equal "PRIVMSG sr :Look Ma, new tests!\n", @server.gets
    end
  end

  class TestShouter < Test::Unit::TestCase
    def create_shouter(&block)
      shouter = ShoutBot.new("irc.freenode.net", 6667, "shouter") {}
      mock(ShoutBot).new(anything, anything, anything, anything).yields(shouter) {shouter}
      shouter
    end

    test "raises error unless block is given" do
      assert_raises ArgumentError do
        ShoutBot.shout("irc://shouter@irc.freenode.net:6667/foo")
      end
    end

    test "creates a new instance of shoutbot" do
      mock(ShoutBot).new("irc.freenode.net", 6667, "shouter", nil)
      ShoutBot.shout("irc://shouter@irc.freenode.net:6667/foo") {}
    end

    test "creates a new instance of shoutbot with password" do
      mock(ShoutBot).new("irc.freenode.net", 6667, "shouter", "badass")
      ShoutBot.shout("irc://shouter:badass@irc.freenode.net:6667/foo") {}
    end

    test "joins channel" do
      shouter = create_shouter
      mock(shouter).join("integrity")
      ShoutBot.shout("irc://shouter@irc.freenode.net:6667/#integrity") {}
    end

    test "says stuff in channel" do
      shouter = create_shouter
      mock(shouter).say("foo bar!")
      ShoutBot.shout("irc://shouter@irc.freenode.net:6667/#integrity") do |bot|
        bot.say "foo bar!"
      end
      assert_equal "#integrity", shouter.channel
    end

    test "sends private message to nick" do
      shouter = create_shouter
      mock(shouter).say("foo bar!")
      ShoutBot.shout("irc://shouter@irc.freenode.net:6667/harry") do |bot|
        bot.say "foo bar!"
      end
      assert_equal "harry", shouter.channel
    end
  end
end
