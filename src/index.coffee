_ = require('lodash')

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

# Logging.
# replaceBetween().
replaceBetween = (start, end, what) ->
  @substring(0, start) + what + @substring(end)

# handleChatter().
handleChatter = (username) ->
  viewers = firebase.child('viewers')
  viewers.child(username).once 'value', (snapshot) ->
    unless snapshot.val()?
      robot.http("https://api.twitch.tv/kraken/users/#{username}").get() (err, res, body) ->
        json = {'display_name': body.display_name or username, 'username': username}
        viewers.child(username).set json, (error) ->
          console.log "#{username} has been added to Firebase."

# handleMessage().
handleMessage = (channel, user, message, is_action) ->
  # The meat of the entire operation. Pushes a payload containing a message,
  # emotes, roles, and usernames to Firebase.
  firebase.child('viewers').child(user.username).once 'value', (snapshot) ->
    data = snapshot.val() or []
    payload =
      # User data.
      'username': user.username
      'display_name': data?.display_name or user.username
      'color': user.color or '#ffffff'
      'roles': _.uniq(user.special)

      # Message data.
      'message': message
      'timestamp': _.now()
      'is_action': is_action

      # Payload version.
      # This is mainly so we can pick out which messages are which in Firebase.
      'version': '2'

    # Send the message to firebase!
    messages = firebase.child('messages').push()
    messages.setWithPriority payload, _.now()

  console.log message
  console.log _.uniq(user.special)  # Special statuses for the user.
  console.log user.emote  # Emoticons.
  console.log user.color  # Colors.

# Listeners. Events sent to 'action' or 'chat' are sent to handleMessage().
# They're both essentially the same except for the fact that we mark one
# as an action and the other not.
client.addListener 'action', (channel, user, message) ->
  handleMessage channel, user, message, true

client.addListener 'chat', (channel, user, message) ->
  handleMessage channel, user, message, false

# Events.
client.addListener 'hosted', (channel, username, viewers) ->
  pusher.trigger 'live', 'hosted',
    username: username

client.addListener 'subscription', (channel, username) ->

client.addListener 'subanniversary', (channel, username, months) ->
