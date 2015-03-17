_ = require('lodash')

# Environment loading.
dotenv = require('dotenv')
dotenv.load()

# Request.
request = require('request')

# Firebase.
Firebase = require('firebase')
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
      return newTokens
    ), tokens)

    if tokenizedMessage[tokenizedMessage.length - 1] == ''
      tokenizedMessage.pop()
    return tokenizedMessage
  return tokens

# handleChatter().
handleChatter = (username) ->
  viewers = firebase.child('viewers')
  viewers.child(username).once 'value', (snapshot) ->
    unless snapshot.val()?
      options =
        url: "https://api.twitch.tv/kraken/users/#{username}"
        headers: 'Content-Type': 'application/json'
      request.get options, (err, res, body) ->
        body = JSON.parse(body)
        json = {'display_name': body.display_name or username, 'username': username}
        viewers.child(username).set json, (error) ->
          client.logger.info "#{username} has been added to Firebase."

# handleMessage().
handleMessage = (channel, user, message, is_action) ->
  # Tokenize and emoticonize the message first.
  tokenizedMessage = emoticonize([message], user.emote)

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
  # First, push the data to Pusher to power the notification.
  pusher.trigger 'live', 'hosted',
    username: username
  client.logger.info "We've been hosted by #{username}."

  # Get the status of the Episode from the API.
  request.get 'http://avalonstar.tv/live/status/', (err, res, body) ->
    episode = JSON.parse(body)

    # Let's record this host to the Avalonstar API -if- and only if the
    # episode is marked as episodic.
    if episode.is_episodic
      json = JSON.stringify
        'broadcast': episode.number
        'hoster': username
        'timestamp': new Date(Date.now()).toISOString()
      options =
        form: json
        url: "http://avalonstar.tv/api/hosts/#{username}/"
        headers: 'Content-Type': 'application/json'
      request.post options, (err, res, body) ->
        if err
          client.logger.error "The host by #{username} couldn't be recorded: #{body}"
          return
        client.logger.info "The host by #{username} was recorded: #{body}"

# Subscriptions.
# activateSubscriber().
activateSubscriber = (username, callback) ->
  # Take the name and push it on through.
  puser.trigger 'live', 'resubscribed',
    username: username
  client.logger.info "#{username} has just re-subscribed!"

  # Update the ticket using the API.
  json = JSON.stringify
    'is_active': true
  options =
    form: json
    url: "http://avalonstar.tv/api/tickets/#{username}/"
    headers: 'Content-Type': 'application/json'
  request.post options, (err, res, body) ->
    # Success message.
    ticket = JSON.parse(body)
    statusCode = res.statusCode
    callback ticket, statusCode

# addSubscriber().
addSubscriber = (username, callback) ->
  # Take the name and push it on through.
  pusher.trigger 'live', 'subscribed',
    username: username
  client.logger.info "#{username} has just subscribed!"

  # Create the ticket using the API.
  json = JSON.stringify
    'name': username
    'is_active': true
  options =
    form: json
    url: 'http://avalonstar.tv/api/tickets/'
    headers: 'Content-Type': 'application/json'
  request.post options, (err, res, body) ->
    # Success message.
    ticket = JSON.parse(body)
    statusCode = res.statusCode
    callback ticket, statusCode

client.addListener 'subscription', (channel, username) ->
  request.get "http://avalonstar.tv/api/tickets/#{username}/", (err, res, body) ->
    # This is a re-subscription.
    # The user has been found in the API; they've been a subscriber.
    if res.statusCode is 200
      activateSubscriber username, (ticket, status) ->
        client.logger.info "#{username}'s ticket reactivated successfully." if status is 200
      return
    # This is a new subscription.
    # The user hasn't been found in the API, so let's create it.
    else if res.statusCode is 404
      addSubscriber username, (ticket, status) ->
        client.logger.info "#{username}'s ticket added successfully." if status is 200
      return

client.addListener 'subanniversary', (channel, username, months) ->
  pusher.trigger 'live', 'substreaked',
    username: username
    length: months
  client.logger.info "#{username} has been subscribed for #{months} months!"

# Cleared chat.
client.addListener 'timeout', (channel, username) ->
  # CLEARCHAT without a name will clear the entire chat on Twitch web. Do not
  # respect that, lest we purge things that we don't want to purge.
  message = firebase.child('messages')
  if username
    # Find the last ten messages from the user to purge (we don't choose
    # more because a purge will rarely cover that many lines).
    message.orderByChild('username').endAt(username).limitToLast(10).once 'value', (snapshot) ->
      snapshot = snapshot.val()
      snapshot.forEach (message) ->
        # Because of Firebase quirks, if it finds less than 10 results for the
        # username, it will find similarly spelled results. Let's not purge the
        # wrong username please.
        username = message.child('username').val()
        if username is username
          client.logger.info "\"#{message.child('message').val()}\" by #{username} has been purged."
          message.ref().child('is_purged').set(true)
