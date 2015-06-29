_ = require('lodash')
request = require('request')

# Event listeners.
module.exports = (client) ->
  # Hosting functionality.
  client.on 'hosted', (channel, username) ->
    # Grab the status from the API.
    request.get 'http://avalonstar.tv/live/status', (err, res, body) ->
      episode = JSON.parse(body)

      json =
        'broadcast': if episode.is_episodic then episode.number else false
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

  # Raid functionality.
  # Handles the backend functions of a raid: looking up the raider via Twitch's
  # API, and recording it. This differs from the rest of the events since it's
  # triggered by a chat command.
  client.on 'chat', (channel, user, message) ->
    if message.indexOf('!raider') == 0
      params = message.split(' ')
      request.get "https://api.twitch.tv/kraken/channels/#{params[1]}", (err, res, body) ->
        streamer = JSON.parse(body)

        if streamer.status == 404
          client.log.error "#{params[1]} doesn't exist."
          return

        # Grab the status from the API.
        request.get 'http://avalonstar.tv/live/status', (err, res, body) ->
          episode = JSON.parse(body)

          json =
            'broadcast': if episode.is_episodic then episode.number else false
            'game': streamer.game
            'username': streamer.name
            'timestamp': new Date(_.now()).toISOString()
          options =
            form: json
            url: 'http://avalonstar.tv/api/raids/'
            headers: 'Content-Type': 'application/json'
          request.post options, (err, res, body) ->
            if err
              client.log.error "The raid by #{username} couldn't be recorded: #{err}, #{body}"
              return
            client.log.info "The raid by #{username} was recorded: #{body}"
