XWrap Postgres Adapter
======================


    Promise = require 'bluebird'
    pg = require 'pg'
    Promise.promisifyAll(pg)
    escape = require 'pg-escape'

    class PostgresAdapter

      constructor: (@options)->
        @._connect = pg.connect
        @features = xwrap:
          basic: true
          subtransactions: true
          wrap: true
          clientMethods: [ 'queryAsync' ]
          clientDataAttributes: [ 'connectionParameters' ]

Low-level interface.

      getRawClient: ()->
        self = this
        close = null
        new Promise (res, rej)->
          self._connect.call pg, self.options, (err, client, done)->
            if err?
              return rej(err)
            close = done
            res(client)
        .disposer ->
          close() if close?

      openTransaction: (client)->
        client.queryAsync('begin')

      commitTransaction: (client)->
        client.queryAsync('commit')

      rollbackTransaction: (client)->
        client.queryAsync('rollback')

      openSubTransaction: (client, name)->
        client.queryAsync "savepoint #{escape.ident(name)}"

      commitSubTransaction: (client, name)->
        client.queryAsync "release #{escape.ident(name)}"

      rollbackSubTransaction: (client, name)->
        client.queryAsync "rollback to #{escape.ident(name)}"

Wrap pg, so that other callers will get a client in transaction
if there is an open transaction above us.

Wraps "connect" which is typical interface to pool. Currently doesn't wrap
"new Client()" as this is often used to assure a standalone connection.

      wrap: ->
        self = this
        pg.connect = (connStr, callback)->
          self.getRawClient()
          .catch (err)->
            callback(err, null, null)
            throw err
          .then (client)->
            new Promise (res, rej)->
              callback null, client, (err)->
                return rej(err) if err?
                res()

    module.exports = (settings)->
      new PostgresAdapter(settings)