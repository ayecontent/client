"use strict"

class InstanceError extends Error
  name: "InstanceError"
  constructor: (@message = "Wrong instance of object") ->
    super
    Error.captureStackTrace(@, InstanceError)





stringifyError = (err) ->
  plainObject = {}
  Object.getOwnPropertyNames(err).forEach((key)->
    plainObject[key] = err[key];
  )
  cache = []
  result = JSON.stringify(plainObject, (key, value) ->
    if (typeof value == 'object' && value != null)
      if(cache.indexOf(value) != -1)
          # Circular reference found, discard key
          return
      # Store value in our collection
      cache.push(value)
    return value
  );
  cache = null # Enable garbage collection
  result

assertInstance = (obj, constructor)->
  throw new InstanceError() if not (obj instanceof constructor)

module.exports =
  InstanceError: InstanceError
  assertInstance: assertInstance
  stringifyError: stringifyError
