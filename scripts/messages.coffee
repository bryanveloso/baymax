# Messaging listeners.
module.exports = (client) ->
  console.log 'heeeyyyyyyy...'

  # Listeners.
  # client.on 'action', (channel, user, message, self) ->
  # client.on 'chat', (channel, user, message, self) ->

  # Cleared chat.
  client.on 'timeout', (channel, username) ->
    client.log.info "DEBUG: Timeout called on #{username}."

    # Find the last ten messages from the user to purge (we don't choose
    # more because a purge will rarely cover that many lines).
    message = firebase.child('messages')
    message.orderByChild('username').equalTo(username).limitToLast(10).once 'value', (data) ->
      data.forEach (message) ->
        client.logger.info "\"#{message.child('message').val()}\" by #{username} has been purged."
        message.ref().child('is_purged').set(true)
