# Test wrap pg

Test wrapping "pg" package: nested call to connect
(such as may be in a library) will get a client in
a transaction if that library is using progress-supporting
promises.

    Promise = require 'bluebird'
    {should, settings} = require './init'
    pg = require 'pg'
    Promise.promisifyAll(pg)

    describe 'wraps pg', ->
      xtransaction = null
      before ->
        {xtransaction} = global.getXWrap()

      it.skip '.connect returns transaction client', ->
        xtransaction (transaction)->
          pg.connectAsync(settings).spread (client)->
            client.queryAsync('select 1')
