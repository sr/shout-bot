require 'rubygems'
require 'addressable/uri'
require 'socket'

class IRC
  def self.shoot(uri, options={}, &block)
    raise ArgumentError unless block_given?

    uri = Addressable::URI.parse(uri)
    irc = new(uri.host, uri.port, options.delete(:as))
    irc.join(uri.path[1..-1], &block)
  end

  def initialize(server, port, nick)
    @socket = TCPSocket.open(server, port)
    @socket.puts "NICK #{nick}"
    @socket.puts "USER #{nick} #{nick} #{nick} :#{nick}"
  end

  def join(channel)
    raise ArgumentError unless block_given?

    @channel = "##{channel}"
    @socket.puts "JOIN #{@channel}"
    yield self
    @socket.puts "PART #{@channel}"
    @socket.puts "QUIT"
    @socket.gets until @socket.eof?
  end

  def say(message)
    @socket.puts "PRIVMSG #{@channel} :#{message}"
  end
end

if $0 == __FILE__
  IRC.shoot('irc://irc.freenode.net:6667/integrity', :as => "Integrity#{rand(20)}") do |channel|
    channel.say "harryjr, check me out! http://gist.github.com/25886"
  end
end
