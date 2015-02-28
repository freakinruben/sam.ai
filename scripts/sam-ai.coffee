# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md
Url = require "url"
Redis = require "redis"
_ = require "underscore"

module.exports = (robot) ->

  redisUrl = if process.env.REDISTOGO_URL?
               redisUrlEnv = "REDISTOGO_URL"
               process.env.REDISTOGO_URL
             else if process.env.REDISCLOUD_URL?
               redisUrlEnv = "REDISCLOUD_URL"
               process.env.REDISCLOUD_URL
             else if process.env.BOXEN_REDIS_URL?
               redisUrlEnv = "BOXEN_REDIS_URL"
               process.env.BOXEN_REDIS_URL
             else if process.env.REDIS_URL?
               redisUrlEnv = "REDIS_URL"
               process.env.REDIS_URL
             else
               'redis://localhost:6379'

  if redisUrlEnv?
    robot.logger.info "Discovered redis from #{redisUrlEnv} environment variable"
  else
    robot.logger.info "Using default redis on localhost:6379"

  info   = Url.parse  redisUrl, true
  client = Redis.createClient(info.port, info.hostname)

  robot.router.post '/api/register', (req, res) ->
    token = req.body.token
    client.sadd('tokens', token);

    res.send JSON.parse '{ "msg" : "Successfully registered ' + token + '" }'

  robot.respond /hook me up/i, (msg) ->
    currentTime = new Date().getTime()
    client.hset('queue', msg.message.user.id, currentTime, (err, res) ->
      makeMatch msg
    )
    msg.reply "thank you, we're going to hook you up for a video chat, please standby..."

  makeMatch = (msg) ->
    client.hgetall('queue', (err, obj) ->
      queueSize = _.size obj

      if queueSize >= 2
        userID = msg.message.user.id
        userIDs = _.keys(obj)
        if _.contains(userIDs, userID)
          otherUserID = _.chain(userIDs)
            .filter((id) -> return (id != userID))
            .sample(1)
            .value()
          msg.reply "hooking you up with #{otherUserID}"

    )
