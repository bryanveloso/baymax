_ = require('lodash')

# Firebase.
Firebase = require('firebase')
firebase = new Firebase 'https://avalonstar.firebaseio.com/'

deepEqual = require('deep-equal')

# Globals.
hasRun = false

# The "Firehose"
module.exports = (client) ->
  # `discharge()` sends our payload to Firebase, setting the payload's
  # "priority" to the current timestamp.
  discharge = (payload) ->
    firehose = firebase.child('firehose').push()
    firehose.setWithPriority payload, _.now()

  # Firehose: Follows
  # Due to a lack of push functionality in Twitch's API, we use `poll()` to
  # monitor the API's 'follows' endpoint.
  poll = ->
    client.api {
      url: 'https://api.twitch.tv/kraken/channels/avalonstar/follows'
      method: 'GET'
      headers:
        'Accept': 'application/vnd.twitchtv.v3+json'
    }, (err, res, body) ->
      body = JSON.parse(body)
      # Return if the Twitch API eats shit.
      if err
        client.log.error err
        return

      console.log body.follows
      return

  setInterval(poll, 10000)

  # Firehose: Subscriptions
  # TODO: There's a difference between subs and resubs. Address that.
  client.on 'subscription', (channel, username) ->
    payload =
      'channel': channel
      'username': username
    discharge payload

  # Firehose: Substreaks
  client.on 'subanniversary', (channel, username, length) ->
    payload =
      'channel': channel
      'username': username
      'length': length
    discharge payload
