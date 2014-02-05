"use strict"

class InstanceError extends Error
  name: "InstanceError"
  constructor: (@message = "Wrong instance of object") ->
    super
    Error.captureStackTrace(@, InstanceError)

stringifyError = (err, filter, space) ->
  plainObject = {}
  Object.getOwnPropertyNames(err).forEach((key)->
    plainObject[key] = err[key];
  )
  JSON.stringify(plainObject, filter, space);


assertInstance = (obj, constructor)->
  throw new InstanceError() if not (obj instanceof constructor)

module.exports =
  InstanceError: InstanceError
  assertInstance: assertInstance
  stringifyError: stringifyError