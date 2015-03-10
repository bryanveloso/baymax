var irc = require('twitch-irc');

var client = new irc.client({
  options: {
    debug: true,
    debugIgnore: ['ping'],
    debugDetails: true,
    logging: true,
  },
  identity: {
    username: process.env.TWITCH_IRC_USERNAME,
    password: process.env.TWITCH_IRC_PASSWORD
  },
  channels: [process.env.TWITCH_IRC_ROOMS.split(',')]
});

client.connect();
