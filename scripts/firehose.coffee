_ = require('lodash')
deepEqual = require('deep-equal')

# Globals.
hasRun = false

# The "Firehose"
module.exports = (client) ->
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
