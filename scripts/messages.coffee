_ = require('lodash')

# Firebase.
Firebase = require('firebase')
firebase = new Firebase 'https://avalonstar.firebaseio.com/'

# Messaging listeners.
module.exports = (client) ->
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
        # Since emoticons are ordered in order of last appearance to first, we
        # can expect the first token to always contain the next emoticon.
        newTokens = []
        token = tokens.shift()
        counter = 0

        # For every token, check the length of the token and if it is less than
        # the index of the emoticon, grab the next token and add to the counter.
        while counter + getLengthOfToken(token) - 1 < emoticon.index[0]
          newTokens.push token
          counter += getLengthOfToken(token)
          token = tokens.shift()

        if !_.isObject(token)
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

  # handleMessage().
  handleMessage = (channel, user, message, is_action) ->
    # Tokenize and emoticonize the message first.
    tokenizedMessage = emoticonize([message], user.emotes)

    # The meat of the entire operation. Pushes a payload containing a message,
    # emotes, roles, and usernames to Firebase.
    payload =
      # User data.
      'username': user.username
      'display_name': user['display-name'] or user.username
      'color': user.color or '#ffffff'
      'role': user['user-type'] or ''
      'subscriber': user.subscriber or false
      'turbo': user.turbo or false

      # Message data.
      'message': tokenizedMessage.join('')
      'timestamp': _.now()
      'is_action': is_action

    # Send the message to firebase!
    messages = firebase.child('messages').push()
    messages.setWithPriority payload, _.now()

  # Listeners.
  client.on 'action', (channel, user, message, self) ->
    handleMessage channel, user, message, true

  client.on 'chat', (channel, user, message, self) ->
    handleMessage(channel, user, message, false) if user isnt 'twitchnotify'

  # Cleared chat.
  client.on 'timeout', (channel, username) ->
    client.log.info "DEBUG: Timeout called on #{username}."

    # Find the last ten messages from the user to purge (we don't choose
    # more because a purge will rarely cover that many lines).
    message = firebase.child('messages')
    message.orderByChild('username').equalTo(username).limitToLast(10).once 'value', (data) ->
      data.forEach (message) ->
        client.log.info "\"#{message.child('message').val()}\" by #{username} has been purged."
        message.ref().child('is_purged').set(true)
