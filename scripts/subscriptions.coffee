_ = require('lodash')
request = require('request')

# Firebase.
Firebase = require('firebase')
firebase = new Firebase 'https://avalonstar.firebaseio.com/'

# Subscription listeners.
module.exports = (client) ->
  postSubscriberMessage = (message) ->
    payload =
      # User data.
      'username': 'twitchnotify'
      'display_name': 'twitchnotify'
      'color': '#ffffff'
      'message': message
      'timestamp': _.now()
      'is_action': false
      'subscriber': false

    # Send the message to firebase!
    messages = firebase.child('messages').push()
    messages.setWithPriority payload, _.now()

  client.on 'subscription', (channel, username) ->
    request.get "http://avalonstar.tv/api/tickets/#{username.toLowerCase()}/", (err, res, body) ->
    # This is a re-subscription.
    # The user has been found in the API; they've been a subscriber.
    if res.statusCode is 200
      # Update the ticket using the API.
      json =
        'is_active': true
        'updated': new Date(_.now()).toISOString()
      options =
        form: json
        url: "http://avalonstar.tv/api/tickets/#{username.toLowerCase()}/"
        headers: 'Content-Type': 'application/json'
      request.put options, (err, res, body) ->
        client.logger.info "#{username}'s ticket reactivated successfully." if res.statusCode is 200
        postSubscriberMessage "Welcome #{username} back to the Crusaders!"
      return
    # This is a new subscription.
    # The user hasn't been found in the API, so let's create it.
    else if res.statusCode is 404
      # Create the ticket using the API.
      json =
        'name': username.toLowerCase()
        'is_active': true
        'created': new Date(_.now()).toISOString()
        'updated': new Date(_.now()).toISOString()
      options =
        form: json
        url: 'http://avalonstar.tv/api/tickets/'
        headers: 'Content-Type': 'application/json'
      request.post options, (err, res, body) ->
        client.logger.info "#{username}'s ticket added successfully." if res.statusCode is 200
        postSubscriberMessage "#{username} just subscribed! Welcome to the Crusaders!"
      return

  client.on 'subanniversary', (channel, username, length) ->
    # Update the ticket using the API.
    json =
      'is_active': true
      'updated': new Date(_.now()).toISOString()
      'streak': months
    options =
      form: json
      url: "http://avalonstar.tv/api/tickets/#{username.toLowerCase()}/"
      headers: 'Content-Type': 'application/json'
    request.put options, (err, res, body) ->
      client.logger.info "#{username}'s substreak added successfully." if res.statusCode is 200
      postSubscriberMessage "#{username}, thank you for your #{months} months as a Crusader!"
    return
