require 'shout_bot'

ShoutBot.new('shout_bot', 'irc.freenode.net', 6667) do |bot|
  bot.join "#awesome_channel" do |c|
    c.shout "This is stupid."
    c.shout "And retarded."
    c.shout "But, I stay!"
  end
  bot.join "#not_awesome" do |c|
    c.shout "This is stupid."
    c.shout "And retarded."
    c.shout "I quit!"
  end
end
