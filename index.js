// require coffee if possible; js otherwise
try {
  require('coffeescript/register');
  postgres = require('./src/postgres');
}
catch (e) {
  postgres = require('./lib/postgres');
}
module.exports = postgres;
