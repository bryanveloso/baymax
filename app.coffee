# Environment loading.
dotenv = require('dotenv')
dotenv.load()

# TMI.js configuration.
tmi = require('tmi.js')
options =
  options:
    debug: true
  connection:
    server: '192.16.64.145'
  identity:
    username: process.env.TWITCH_IRC_USERNAME
    password: process.env.TWITCH_IRC_PASSWORD
  channels: [ process.env.TWITCH_IRC_ROOMS ]

client = new tmi.client(options)
client.connect()

fs = require('fs')
console.log fs.existsSync('scripts/')

# Listeners.
# client.on 'action', (channel, user, message, self) ->
# client.on 'chat', (channel, user, message, self) ->

# TODO: Add raid recording functionality.
