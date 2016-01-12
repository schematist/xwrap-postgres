XWrap Postgres Adapter
======================


    Promise = require 'bluebird'
    pg = require 'pg'
    Promise.promisifyAll(pg)
    escape = require 'pg-escape'

    _connect = pg.connect

    class PostgresAdapter

      constructor: (@options)->
        @features = xwrap:
          basic: true
          subtransactions: true
          wrap: true
          clientMethods: [ 'queryAsync' ]
          clientDataAttributes: [ 'connectionParameters' ]

      close: ()->
        xwrap = require 'xwrap'
        return xwrap.disconnect(@id)

      disconnect: ()->
        pool = pg.pools.all[JSON.stringify(@options)]
        Promise.try ->
          return if !pool?
          return new Promise (res)->
            pool.drain ->
              pool.destroyAllNow(res)


Low-level interface.

      getRawClient: ()->
        self = this
        close = null
        new Promise (res, rej)->
          _connect.call pg, self.options, (err, client, done)->
            if err?
              return rej(err)
            close = done
            res(client)
        .disposer ->
          close() if close?

Convenience interface for shared client in transaction, or standard
client out of transaction if no transaction.

      getClient: (callerName)->
        self = this
        @xtransaction.client(callerName).then (client)->
          return client ? self.getRawClient()

      withClient: (callerName, cb)->
        if typeof cb != 'function'
          cb = callerName
          callerName = '???'
        @getClient(callerName).then (cpromise)->
          Promise.using(cpromise, cb)

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

** NOT WORKING **

1) We need to wrap async version only so we have access to client.
2) "done" -- dummy passed to client, but we are actually done when
  promise returned by callback resolves.

3) Impossible to wrap raw "connect"...

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

    module.exports = initialize = (settings)->
      new PostgresAdapter(settings)
    initialize.PostgresAdapter = PostgresAdapter