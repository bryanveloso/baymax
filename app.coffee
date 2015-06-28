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

# Load scripts.
fs = require('fs')
path = './scripts/'
if fs.existsSync(path)
  for file in fs.readdirSync(path).sort()
    require(path + file) client

# TODO: Add raid recording functionality.
