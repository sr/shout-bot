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
