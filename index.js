// require coffee if possible; js otherwise
try {
  try { require('coffee-script/register'); } catch (e) {}  
  postgres = require('./src/postgres');
}
catch (e) {
  if(e.message.indexOf("Cannot find module") != -1 
      && (e.message.indexOf('./src/index') != -1 
        || e.message.indexOf('coffee-script/register') != -1))
    postgres = require('./lib/postgres');
  else
    throw e;
}
module.exports = postgres;