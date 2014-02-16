crypto = require "crypto"
config = require "config"

hash = crypto.createHmac('sha1', "secret12345678").update(config.get("client:id")).digest('base64')

console.log hash

