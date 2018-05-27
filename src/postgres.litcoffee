XWrap Postgres Adapter
======================


    Promise = require 'bluebird'
    pg = require 'pg'
    Promise.promisifyAll(pg)
    escape = require 'pg-escape'

    _connect = (config, cb) =>
      pool = new pg.Pool(config)
      return pool.connect(cb)

    class PostgresAdapter

      constructor: (@options)->
        # separate out effective options for postgres to ensure
        # pool has unique identity.
        @_dbOptions = o = {
          database: @options.database ? process.env.PGDATABASE
          host: @options.host  ? process.env.PGHOST ? 'localhost'
          port: @options.port ? process.env.PGPORT ? '5432'
          ssl: @options.ssl ? process.env.PGSSLMODE
          user: @options.user ? process.env.PGUSER
        }
        @_dbOptions.url = "postgres://" + o.user +
          '@' + o.host + ':' + o.port +
          '/' + o.database + '?ssl=' + (o.ssl || false)

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
        self = this
        key = @_dbOptions.url
        console.log("pools", Object.keys(pg._pools))
        poolKey = if pg._pools then '_pools' else 'pools'
        pool = pg[poolKey]?[key]
        Promise.try ->
          return if !pool?
          pool = pool.pool if pool.pool?
          return new Promise (res)->
            pool.drain ->
              pool.destroyAllNow ()->
                delete pg[poolKey]?[key]
                res()
        .finally ->
          self.close()

Low-level interface.

      getRawClient: ()->
        self = this
        close = null
        new Promise (res, rej)->
          _connect self._dbOptions, (err, client, done)->
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
