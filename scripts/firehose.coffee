_ = require('lodash')
EventSource = require('eventsource')
request = require('request')

# Firebase.
Firebase = require('firebase')
firebase = new Firebase process.env.FIREBASE_URL

# The "Firehose"
module.exports = (client) ->
  # `discharge()` sends our payload to Firebase, setting the payload's
  # "priority" to the current timestamp. We do not set the name of the Firebase
  # endpoint to 'firehose' because Ember (and Emberfire) pluralize the key.
  discharge = (payload) ->
    firehose = firebase.child('events').push()
    firehose.setWithPriority payload, payload.timestamp
    client.log.info "#{_.capitalize(payload.event)} event for #{payload.username} posted successfully."

  # Firehose: Follows
  # Prefill.
  cache = []
  client.api {
    url: 'https://api.twitch.tv/kraken/channels/avalonstar/follows?limit=100'
    method: 'GET'
    headers:
      'Accept': 'application/vnd.twitchtv.v3+json'
  }, (err, res, body) ->
    body = JSON.parse(body)

    # Return if the Twitch API eats shit.
    if err
      client.log.error err
      return

    body.follows.forEach (follower) ->
      snapshot =
        'timestamp': follower.created_at
        'username': follower.user.display_name
      cache.push snapshot
    client.log.info "#{body.follows.length} preloaded into the follow cache."

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

      body.follows.forEach (follower) ->
        snapshot =
          'timestamp': follower.created_at
          'username': follower.user.display_name
        if _.some(cache, snapshot)
          return
        cache.push snapshot
        console.log snapshot

        # We have new followers! Let's push them along.
        payload =
          'event': 'follow'
          'timestamp': Date.parse(snapshot.timestamp)
          'username': snapshot.username
        discharge payload
  setInterval(poll, 1000 * 10)  # 10 seconds.

  # Firehose: Subscribed
  # TODO: There's a difference between subs and resubs. Address that.
  client.on 'subscription', (channel, username) ->
    payload =
      'event': 'subscription'
      'timestamp': _.now()
      'username': username
    discharge payload

  # Firehose: Substreaked
  client.on 'subanniversary', (channel, username, length) ->
    payload =
      'event': 'substreak'
      'timestamp': _.now()
      'username': username
      'length': length
    discharge payload

  # Firehose: Hosted
  client.on 'hosted', (channel, username, viewers) ->
    payload =
      'event': 'host'
      'timestamp': _.now()
      'username': username
    discharge payload

  # Firehose: Raided
  client.on 'chat', (channel, user, message) ->
    if message.indexOf('!raider') == 0
      params = message.split(' ')
      request.get "https://api.twitch.tv/kraken/channels/#{params[1]}", (err, res, body) ->
        streamer = JSON.parse(body)

        if streamer.status == 404
          return

        payload =
          'event': 'raid'
          'timestamp': _.now()
          'username': streamer.name
        discharge payload

  # Firehose: Tipped
  es = new EventSource("https://imraising.tv/api/v1/listen?apikey=#{process.env.IMR_API_KEY}")
  es.addEventListener 'donation.add', (e) ->
    body = JSON.parse(e.data)
    payload =
      'event': 'tip'
      'timestamp': _.now()
      'username': body.nickname
      'message': body.message
      'amount': body.amount.display.total
    discharge payload
