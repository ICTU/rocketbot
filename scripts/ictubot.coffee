_ = require 'lodash'
jenkins = require 'jenkins'

JENKINS_URL = process.env.JENKINS_URL
SEMANTIQL_URL = process.env.SEMANTIQL_URL

POWER_COMMANDS = [
  'ssh.execute.command' # String that matches the listener ID
  'semantiql.query'
]

ADMINS = process.env.ADMINS?.split(',').map (admin) -> admin.trim()


module.exports = (robot) ->
  querySemantiql = (gql, cb) ->
    robot.http("#{SEMANTIQL_URL}/api")
      .header('Content-Type', 'application/json')
      .post(JSON.stringify(query: gql)) (err, res, body) ->
        if err
          console.error err
          cb? []
        else
          console.log "#{JSON.stringify(JSON.parse(body).data, null, 3)}"
          cb? JSON.parse(body)?.data

  inProjectRoom = (res, cb) ->
    gql = """{projects(rocketChatRoomId: "#{res.message.room}"){ name }}"""
    querySemantiql gql, (result) ->
      unless result.projects.length
        res.send "Ooh, you're naughty! You know I can only do this in private, project rooms ;)"
      else
        cb? result.projects[0].name?.toLowerCase()

  robot.router.post '/zabbix', (req, res) ->
    data = JSON.parse req.body.payload
    fields = data.attachments[0].fields
    host = _.find fields, title: 'Host'
    gql = """{projects(host: "#{host?.value}"){ rocketChatRoomId }}"""
    querySemantiql gql, (result) ->
      for project in result.projects
        robot.messageRoom project.rocketChatRoomId, data if project?.rocketChatRoomId
    res.send 'OK'

  robot.listenerMiddleware (context, next, done) ->
    if context.listener.options.id in POWER_COMMANDS
      if context.response.message.user.name in ADMINS
        next()
      else
        context.response.reply "I'm sorry, @#{context.response.message.user.name}. I cannot allow you to that, because you do not have the right authorization level."
        done()
    else
      next()

  robot.respond /show all fields/i, { id: "semantiql.query"}, (res) ->
    gql = """{__type(name: "Project"){ fields{name} }}"""
    querySemantiql gql, (result) ->
      if result?.__type?.fields?.length
        res.send """
        ```
        #{JSON.stringify(result.__type.fields, null, 3)}
        ```
        """
      else
        res.send "Failed to retrieve available fields."

  robot.respond /show (.*) for (.*) is (.*)/i, { id: "semantiql.query" }, (res) ->
    requestFieldName = res.match[1]
    queryFieldName = res.match[2]
    queryFieldValue = res.match[3]
    gql = """{projects(#{queryFieldName}: "#{queryFieldValue}"){ #{requestFieldName} }}"""

    querySemantiql gql, (result) ->
      if result?.projects?.length
        res.send """
        ```
        #{JSON.stringify(result.projects, null, 3)}
        ```
        """
      else
        res.send "Failed to retrieve #{requestFieldName} for #{queryFieldName}: #{queryFieldValue}. Your query may be incorrect"

  robot.respond /help/i, (res) ->
    res.send """
    Hello #{res.message.user.name}, I am the gorgeous ICTU ISD automation bot.
    Prefix the commands below with my name, so I know you are talking to me:

    *help*
        I will display this message.

    *clean docker registry*
        I will start a garbage collection process in your project docker registry.
        To avoid data corruption, I will first stop the docker registry.
        Once the garbage collection is done, I will start the docker registry for you.
        You can only issue this command from a private room with the name of your project, for example 'rws'.

    *clean local docker graph*
        I will remove all non-running containers and remove dangling images and volumes.
        You can only issue this command from a private room with the name of your project, for example 'rws'.
    """
  robot.respond /for (.*) execute command: `(.*)`/i, { id: "ssh.execute.command" }, (res) ->
    project = res.match[1]
    command = res.match[2]
    userOrRoom = "@#{res.message.user.name}"
    runCommandOnHosts project,
      userOrRoom,
      command
    , (err, nr) ->
        if err
          console.error err
          res.send """I could execute your command, because
                    #{err}."""
        else
          res.send """Ok, i'm going to pass your commands to the server(s).
                    I'll let you know when the execution is done."""

  robot.respond /clean local docker graph/i, (res) ->
    inProjectRoom res, (project) ->
      userOrRoom = "##{project}"
      command = "docker rm -v \\$(docker ps -aq) || true; docker rmi \\$(docker images -q) || true; docker volume rm \$(docker volume ls -q) || true"
      runCommandOnHosts project,
        userOrRoom,
        command
      , (err, nr) ->
          if err
            console.error err
            res.send """I could not start cleaning up your host's local docker graph, because
                      #{err}."""
          else
            res.send """I am now trying to clean up your host's local docker graph.
                      I'll let you know when I'm done."""

  robot.respond /clean( my| our)? docker registry/i, (res) ->
    inProjectRoom res, (project) ->
      startJenkinsJob 'garbage-collect-docker-registry',
        projectName: project
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

runCommandOnHosts = (projectName, userOrRoom, command, cb) ->
  startJenkinsJob "run-command-on-hosts",
    TargetEnvironment: projectName
    cmd: command
    userOrRoom: userOrRoom
  , cb

startJenkinsJob = (jobName, params, cb) ->
  client = jenkins
    baseUrl: JENKINS_URL

  client.job.build
    name: jobName
    parameters: params
  , cb
