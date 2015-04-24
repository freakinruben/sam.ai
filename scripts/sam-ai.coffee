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
  lastQueueSize = 0
  queueTimeout = 30 * 60 * 1000 # nr of milliseconds after which someone is removed from the queue

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


  robot.respond /hook\s*me\s*up/i, (msg) ->
    addToQueue(msg.message.user.id, () ->
      makeMatch(msg))
    msg.reply "Hey #{getUserName(msg.message.user)}, it's nice to hear from you. I'm gonna look for a candidate for you."


  makeMatch = (msg) ->
    # read queue hash
    redis.hgetall('queue', (err, obj) ->
      lastQueueSize = _.size obj

      if lastQueueSize >= 2
        userIDs = _.keys(obj)
        userID1 = msg.message.user.id
        getChatHistory(userID1, (user1History) ->
          if _.contains(userIDs, userID1) # check if user-id is in queue
            userID2 = _.chain(userIDs)
              .filter((id) -> return (id != userID1))
              .reject((id) -> return havePreviouslyChatted(user1History, id))
              .sample(1) # random id
              .first()
              .value()

            connectUsers(userID1, userID2)
        )
    )


  connectUsers = (userID1, userID2) ->
    if userID1 and userID2
      videoURL = 'https://room.co/#/sambot-' + userID1 + '-' + userID2
      userName1 = getUserName(userID1)
      userName2 = getUserName(userID2)
      robot.logger.debug "matching #{userName1}; #{userName2}"

      setChatHistory(userID1, userID2)
      sendMsg(userID1, "So I took a quick look, I think you and #{userName2} should chat. I've set up a video-room for you at #{videoURL}.")
      sendMsg(userID2, "Hey, it's Sam.ai, I think you and #{userName} should chat. I've set up a video-room for you at #{videoURL}.")

      removeFromQueue(userID1)
      removeFromQueue(userID2)

    else
      #robot.logger.debug "empty id #{userID1}/#{userID2}"
      sendMsg(userID1, "I took a quick look and couldn't find anyone that's available for a chat right now. I will let you know if I find someone in the coming half hour.")
      sendMsg(userID1, "If you don't want to wait and try another time, let me know by saying 'cancel'.")


  sendMsg = (userID, msg) ->
    user = robot.brain.userForId(userID)
    robot.messageRoom(user.room, msg)


  getUserName = (user) ->
    # user can be string, we then fetch the user from the brain, otherwise we asume `user` is the user-object
    user = if typeof user is "string" then robot.brain.userForId(user) else user
    return if user.real_name.length > 0 then user.real_name else user.name


  havePreviouslyChatted = (user1History, userID2) ->
    #robot.logger.debug("chat history #{user1History} contains #{userID2}? #{_.contains(user1History, userID2)}")
    #redis.sismember(userID1, userID2, (err, result) ->
    return _.contains(user1History, userID2)


  getChatHistory = (userID, callback) ->
    history = null
    redis.smembers  userID, (err, history) ->
      robot.logger.debug("found history for #{userID} : #{history}")
      callback(history)
    #  return obj
    #robot.logger.debug("returning history for #{userID}")
    #return history


  setChatHistory = (userID1, userID2) ->
    robot.logger.debug "set chathistory between #{userID1} and #{userID2}"
    redis.sadd(userID1, userID2)
    redis.sadd(userID2, userID1)


  addToQueue = (userID, callback) ->
    # store user-id in queue with timestamp
    robot.logger.debug "add to queue: #{userID}"
    redis.hset('queue', userID, new Date().getTime(), (err, res) -> callback())


  removeFromQueue = (userID, callback) ->
    robot.logger.debug "remove from queue: #{userID}"
    redis.hdel('queue', userID, (err, res) -> callback())


  searchCommunityMember = (forUser) ->
    return null

