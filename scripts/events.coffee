_ = require('lodash')
request = require('request')

# Listeners.
module.exports = (client) ->
  client.on 'hosted', (channel, username) ->
    # Grab the status from the API.
    request.get 'http://avalonstar.tv/live/status', (err, res, body) ->
      episode = JSON.parse(body)

      json =
        # 'broadcast': if episode.is_episodic then episode.number
        'username': username
        'timestamp': new Date(_.now()).toISOString()
      options =
        form: json
        url: 'http://avalonstar.tv/api/hosts/'
        headers: 'Content-Type': 'application/json'
      request.post options, (err, res, body) ->
        if err
          client.log.error "The host by #{username} couldn't be recorded: #{err}, #{body}"
          return
        client.log.info "The host by #{username} was recorded: #{body}"
