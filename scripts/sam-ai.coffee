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
  redis  = Redis.createClient(info.port, info.hostname)
  prefix = info.path?.replace('/', '') or 'hubot'

  if info.auth
    redis.auth info.auth.split(":")[1], (err) ->
      if err
        robot.logger.error "Sam.ai failed to authenticate to Redis"
      else
        robot.logger.info "Sam.ai successfully authenticated to Redis"

  redis.on "error", (err) ->
    if /ECONNREFUSED/.test err.message

    else
      robot.logger.error err.stack

  redis.on "connect", ->
    robot.logger.debug "Sam.ai successfully connected to Redis"
    #getData() if not info.auth

  robot.router.post '/api/register', (req, res) ->
    token = req.body.token
    redis.sadd('tokens', token);

    res.send JSON.parse '{ "msg" : "Successfully registered ' + token + '" }'


  robot.respond /hook me up/i, (msg) ->
    currentTime = new Date().getTime()
    robot.logger.debug "add to queue: #{msg.message.user.id}"
    # store user-id in queue with timestamp
    redis.hset('queue', msg.message.user.id, currentTime, (err, res) ->
      makeMatch msg
    )
    msg.reply "thank you, we're going to hook you up for a video chat, please standby..."


  makeMatch = (msg) ->
    # read queue hash
    redis.hgetall('queue', (err, obj) ->
      queueSize = _.size obj

      if queueSize >= 2
        userIDs = _.keys(obj)
        userID1 = msg.message.user.id
        if _.contains(userIDs, userID1) # check if user-id is in queue
          userID2 = _.chain(userIDs)
            .filter((id) -> return (id != userID1))
            # .reject((id) -> return havePreviouslyChatted(userID1, id))
            .sample(1) # random id
            .value()

          connectUsers(userID1, userID2)
    )


  connectUsers = (userID1, userID2) ->
    if userID1? and userID2?
      videoURL = 'https://room.co/#/sambot-' + userID1 + '-' + userID2
      userName1 = getUserName(userID1)
      userName2 = getUserName(userID2)
      robot.logger.debug "matching #{userName1}; #{userName2}"

      setChatHistory(userID1, userID2)
      sendMsg(userID1, "hooking you up with #{userName2} at #{videoURL}")
      sendMsg(userID1, "We've matched you with #{userName1} for a videochat. Begin directly at #{videoURL}")
    else
      robot.logger.debug "empty id #{userID1}; #{userID2}"


  sendMsg = (userID, msg) ->
    user = robot.brain.userForId(userID)
    robot.messageRoom user.room msg


  getUserName = (userID) ->
    user = robot.brain.userForId(userID)
    return if user.real_name.length > 0 then user.real_name else user.name


  havePreviouslyChatted = (userID1, userID2) ->
    console.log(getChatHistory(userID1))
    # previouslyChatted = redis.sismember('a', 'b')
    # console.log(util.inspect(redis.sismember))
    # console.log(typeof previouslyChatted + ": #{previouslyChatted}")

    if redis.sismember(userID1, userID2) is 1
      return true
    else
      return false
    # console.log(redis.sismember(userID1, userID2))
    # console.log("have #{userID1} and #{userID2} chatted before? : #{redis.sismember(userID1, userID2)}")
    # return redis.sismember(userID1, userID2)


  getChatHistory = (userID) ->
    return redis.smembers(userID);


  setChatHistory = (userID1, userID2) ->
    redis.sadd(userID1, userID2)
    redis.sadd(userID2, userID1)

