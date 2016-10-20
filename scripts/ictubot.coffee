MongoClient = require('mongodb').MongoClient
jenkins = require 'jenkins'

MONGO_URL = process.env.MONGO_URL
JENKINS_URL = process.env.JENKINS_URL

rooms = null
MongoClient.connect MONGO_URL, (err, db) ->
  console.log "Connected to mongo server at #{MONGO_URL}"
  rooms = db.collection 'rocketchat_room'

module.exports = (robot) ->
  robot.respond /help/i, (res) ->
    res.send """
    This is your friendly ICTU ISD automation bot.
    Commands:
      help - I will display this message.
      clean docker registry - I will start a garbage collection process in your project Docker Registry.
                              To avoid data corruption, I will first stop the docker registry.
                              Once the gabage collection is done, I will start the docker registry for you.
                              You can only issue this command from a private room with the name of your project, for example 'rws'.
    """

  robot.respond /clean( my| our)? docker registry/i, (res) ->
    rooms.findOne {_id: res.message.room}, (err, room) ->
      if err
        console.error err
        res.send """I could not start cleaning up your docker registry, because
                  #{err}."""
      else
        unless room.t is 'p' # the room is private
          res.send "Ooh, you naughty! You know I can only do this in private, project rooms ;)"
        else
          startJenkinsJob 'garbage-collect-docker-registry',
            projectName: room.name
            runType: 'execute'
          , (err, nr) ->
              if err
                console.error err
                res.send """I could not start cleaning up your docker registry, because
                          #{err}."""
              else
                res.send """I am now trying to clean up your docker registry.
                          To do that, I will have to stop it first.
                          Do not worry, I'll start it again, once I am done."""

startJenkinsJob = (jobName, params, cb) ->
  client = jenkins
    baseUrl: JENKINS_URL

  client.job.build
    name: jobName
    parameters: params
  , cb
