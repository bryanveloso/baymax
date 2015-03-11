# Environment loading.
dotenv = require('dotenv')
dotenv.load()

# Firebase.
Firebase = require 'firebase'
firebase = new Firebase 'https://avalonstar.firebaseio.com/'

# Pusher configuration.
Pusher = require('pusher')
pusher = new Pusher
  appId: process.env.PUSHER_APP_ID
  key: process.env.PUSHER_KEY
  secret: process.env.PUSHER_SECRET

# Twitch IRC configuration.
irc = require('twitch-irc')
client = new irc.client(
  options:
    debug: true
    debugIgnore: [ 'ping' ]
    debugDetails: true
    logging: true
  identity:
    username: process.env.TWITCH_IRC_USERNAME
    password: process.env.TWITCH_IRC_PASSWORD
  channels: [ process.env.TWITCH_IRC_ROOMS ])

# Connect to Twitch's IRC.
client.connect()

# Functions.
# replaceBetween().
replaceBetween = (start, end, what) ->
  @substring(0, start) + what + @substring(end)

# listen().
listen = (channel, user, message) ->
  console.log message
  console.log user.username  # Username.
  console.log user.special  # Special statuses for the user.
  console.log user.emote  # Emoticons.
  console.log user.color  # Colors.

# Consider this a scratch area.
# Logging.
client.addListener 'action', (channel, user, message) ->
  listen channel, user, message

client.addListener 'chat', (channel, user, message) ->
  listen channel, user, message

# Events.
client.addListener 'hosted', (channel, username, viewers) ->
  pusher.trigger 'live', 'hosted',
    username: username

client.addListener 'subscription', (channel, username) ->

client.addListener 'subanniversary', (channel, username, months) ->
