# Environment loading.
# This is a bit hacky. We're assuming that we're running locally since
# `process.env.PORT` should only exist when running on Heroku.
if not process.env.PORT
  dotenv = require('dotenv')
  dotenv.load()

# TMI.js configuration.
tmi = require('tmi.js')
options =
  options:
    debug: true
  identity:
    username: process.env.TWITCH_IRC_USERNAME
    password: process.env.TWITCH_IRC_PASSWORD
  channels: [ process.env.TWITCH_IRC_ROOMS ]

client = new tmi.client(options)

# Load scripts.
fs = require('fs')
path = './scripts/'
if fs.existsSync(path)
  for file in fs.readdirSync(path).sort()
    require(path + file) client

client.connect()

# Miscellaneous.
# Bind to a port so the application is kept alive.
http = require('http')
server = http.createServer((request, response) ->
  response.writeHead 200, 'Content-Type': 'application/json'
  response.end '{"greeting": "Hello, I am Baymax, your personal Twitch companion."}'
).listen(process.env.PORT || 8888)
