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
# orderEmoticons().
orderEmoticons = (emoticons) ->
  emotes = Object.keys(emoticons)
  replacements = []

  emotes.forEach (id) ->
    emote = emoticons[id]
    i = emote.length - 1
    while i >= 0
      position = emote[i].split('-')
      replacements.push {'id': id, 'index': [parseInt(position[0], 10), parseInt(position[1], 10)]}
      i--

  replacements.sort (a, b) ->
    return b.index[0] - a.index[0]
  return replacements

# emoticonize().
emoticonize = (tokens, emoticons) ->
  if tokens and emoticons
    emoticons = orderEmoticons(emoticons)

    imgTemplate = (id) ->
      src = "http://static-cdn.jtvnw.net/emoticons/v1/#{id}/1.0"
      srcset = "http://static-cdn.jtvnw.net/emoticons/v1/#{id}/2.0 2x"
      return "<img class=\"emo-#{id} emoticon\" src=\"#{src}\" srcset=\"#{srcset}\">"

    getLengthOfToken = (token) ->
      return token.length

    tokenizedMessage = _.reduce(emoticons, ((tokens, emoticon) ->
      # Since emoticons are ordered in order of last appearance to first, we can
      # expect the first token to always contain the next emoticon.
      newTokens = []
      token = tokens.shift()
      counter = 0

      # For every token, check the length of the token and if it is less than the
      # index of the emoticon, grab the next token and add to the counter.
      while counter + getLengthOfToken(token) - 1 < emoticon.index[0]
        newTokens.push token
        counter += getLengthOfToken(token)
        token = tokens.shift()

      if !_.isObject(token)
        # alttext = token.slice(emoticon.index[0] - counter, emoticon.index[1] + 1 - counter)
        newTokens.push token.slice(0, emoticon.index[0] - counter)
        newTokens.push imgTemplate emoticon.id
        newTokens.push token.slice(emoticon.index[1] + 1 - counter)
        newTokens = newTokens.concat(tokens)
      else
        newTokens = newTokens.concat(token, tokens)
      console.log newTokens
      return newTokens
    ), tokens)

    if tokenizedMessage[tokenizedMessage.length - 1] == ''
      tokenizedMessage.pop()
    console.log tokenizedMessage
    return tokenizedMessage
  return tokens

# handleChatter().
handleChatter = (username) ->
  viewers = firebase.child('viewers')
  viewers.child(username).once 'value', (snapshot) ->
    unless snapshot.val()?
      request.get "https://api.twitch.tv/kraken/users/#{username}", (err, res, body) ->
        json = {'display_name': body.display_name or username, 'username': username}
        viewers.child(username).set json, (error) ->
          console.log "#{username} has been added to Firebase."

# handleMessage().
handleMessage = (channel, user, message, is_action) ->
  console.log "Original message: #{message}"

  # Tokenize and emoticonize the message first.
  tokenizedMessage = emoticonize([message], user.emote)
  console.log "Processed message: " + tokenizedMessage.join('')

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
      'message': tokenizedMessage.join('')
      'timestamp': _.now()
      'is_action': is_action

      # Payload version.
      # This is mainly so we can pick out which messages are which in Firebase.
      'version': '2'

    # Send the message to firebase!
    messages = firebase.child('messages').push()
    messages.setWithPriority payload, _.now()

# Listeners. Events sent to 'action' or 'chat' are sent to handleMessage().
# They're both essentially the same except for the fact that we mark one
# as an action and the other not.
client.addListener 'action', (channel, user, message) ->
  handleChatter user.username
  handleMessage channel, user, message, true

client.addListener 'chat', (channel, user, message) ->
  handleChatter user.username
  handleMessage channel, user, message, false

# Events.
client.addListener 'hosted', (channel, username, viewers) ->
  pusher.trigger 'live', 'hosted',
    username: username

client.addListener 'subscription', (channel, username) ->

client.addListener 'subanniversary', (channel, username, months) ->
