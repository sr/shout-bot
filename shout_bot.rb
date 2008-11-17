require 'socket'

class ShoutBot
  def initialize(nick, server, port=6667)
    @irc = TCPSocket.open(server, port)
    @irc.puts "NICK #{nick}"
    @irc.puts "USER #{nick} #{nick} #{nick} :#{nick}"
    yield self
    @irc.puts "QUIT"
    @irc.gets until @irc.eof?
  end

  def join(channel)
    @irc.puts "JOIN #{channel}"
    @channel = channel
    yield self
    @irc.puts "PART #{channel}"
  end

  def shout(message)
    @irc.puts "PRIVMSG #{@channel} :#{message}"
  end
end
