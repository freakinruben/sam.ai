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
util = require('util');

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
          user = msg.message.user
          userName = user.name

          if user.real_name.length > 0
            userName = user.real_name

          # userName = user.real_name if user.real_name.length > 0 else user.name
          # console.log("incoming video chat from _#{userName}_")

          otherUserID = _.chain(userIDs)
            .filter((id) -> return (id != userID))
            # .reject((id) -> return havePreviouslyChatted(userID, id))
            .sample(1)
            .value()

          if otherUserID?
            setChatHistory(userID, otherUserID)
            otherUser = robot.brain.userForId(otherUserID)
            otherUserName = otherUser.real_name
            msg.reply "hooking you up with #{otherUserName}"
            robot.messageRoom otherUser.room, "incoming video chat from #{userName}"
            # console.log(robot.brain.userForId(otherUserID))
          else
            msg.reply "no other users found"
    )

  havePreviouslyChatted = (firstUserID, secondUserID) ->
    console.log(getChatHistory(firstUserID))
    # previouslyChatted = client.sismember('a', 'b')
    # console.log(util.inspect(client.sismember))
    # console.log(typeof previouslyChatted + ": #{previouslyChatted}")

    if client.sismember(firstUserID, secondUserID) is 1
      return true
    else
      return false
    # console.log(client.sismember(firstUserID, secondUserID))
    # console.log("have #{firstUserID} and #{secondUserID} chatted before? : #{client.sismember(firstUserID, secondUserID)}")
    # return client.sismember(firstUserID, secondUserID)

  getChatHistory = (userID) ->
    return client.smembers(userID);

  setChatHistory = (firstUserID, secondUserID) ->
    client.sadd(firstUserID, secondUserID)
    client.sadd(secondUserID, firstUserID)

