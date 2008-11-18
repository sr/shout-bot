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
