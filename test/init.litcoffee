Setup postgres adapter test.

    xwrap = require 'xwrap'
    fs = require('fs')
    postgres = require '../'

The following needs to be defined before requiring xwrap/test/base

    settings = JSON.parse fs.readFileSync(__dirname + '/config.json')        

    global.getXWrap = ->
      return {
        xtransaction: xwrap
          adapter: postgres(settings)
          settings: settings
          id: 'postgres'
        clientMethods: ['queryAsync']
        query: (client, qstring)->
          client.queryAsync("select '#{qstring}'")
      }

    exports = module.exports = require 'xwrap/test/base'
    exports.settings = settings