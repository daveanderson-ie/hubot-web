Robot = require('hubot').Robot
Adapter = require('hubot').Adapter
TextMessage = require('hubot').TextMessage
request = require('request')
string = require("string")

# sendmessageURL domain.com/messages/new/channel/ + user.channel
sendMessageUrl = process.env.HUBOT_REST_SEND_URL

class WebAdapter extends Adapter
  toHTML: (message) ->
    # message = string(message).escapeHTML().s
    message.replace(/\n/g, "<br>")

  createUser: (username, room) ->
    user = @robot.brain.userForName username
    unless user?
      id = new Date().getTime().toString()
      user = @robot.brain.userForId id
      user.name = username

    user.room = room

    user

  send: (user, strings...) ->
    if strings.length > 0

      message = if process.env.HUBOT_HTML_RESPONSE then @toHTML(strings.shift()) else strings.shift()

      @robot.logger.debug "Sending [#{user.room}] #{@robot.name} => #{user.user.name} #{message} " + JSON.stringify(user.user.options)

      request.post(sendMessageUrl).form({
        message: message,
        room: "#{user.room}",
        from: "#{@robot.name}",
        to: "#{user.user.name}",
        options: JSON.stringify(user.user.options)
      })
      @send user, strings...

  reply: (user, strings...) ->
    @send user, strings.map((str) -> "#{user.user}: #{str}")...

  run: ->
    self = @

    options = {}

    @robot.router.post '/receive/:room', (req, res) ->
      user = self.createUser(req.body.from, req.params.room)

      if req.body.options
        user.options = JSON.parse(req.body.options)
      else
        user.options = {}

      self.robot.logger.debug "Received: [#{req.params.room}] #{user.name} => #{req.body.message} " + JSON.stringify(user.options)

      res.setHeader 'content-type', 'text/html'
      self.receive new TextMessage(user, "#{self.robot.name} #{req.body.message}")
      res.end 'received'

    self.emit "connected"

exports.use = (robot) ->
  robot.logger.info 'Forwarding responses to ' + if sendMessageUrl then sendMessageUrl else 'nowhere'
  new WebAdapter robot
