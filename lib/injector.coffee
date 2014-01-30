"use strict"

class Injector
  @dependencies: {}
  @register: (key, value) ->
    @dependencies[key] = value
  @resolve: () ->
    scope = {}
    args = []
    if typeof arguments[0] == "string"
      func = arguments[1]
      deps = arguments[0].replace(/\ /g,"").split(",")
      scope = arguments[2] if arguments[2]?
    else
      func = arguments[0]
      deps = func.toString().match(/^function\s*[^\(]*\(\s*([^\)]*)\)/m)[1].replace(/\ /g, '').split(',')
      scope = arguments[1] if arguments[1]?
    () =>
      a = Array.prototype.slice.call arguments, 0
      for d in deps
        args.push( if d and Injector.dependencies[d] then Injector.dependencies[d] else a.shift() )
      func.apply scope, args

module.exports = Injector