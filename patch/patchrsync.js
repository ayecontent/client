//Patching existing node js modules
var Rsync = require('rsync');

Rsync.prototype.args = function () {
  // Gathered arguments
  var args = [];

  // Add options. Short options (one letter) without values are gathered together.
  // Long options have a value but can also be a single letter.
  var short = [];
  var long = [];

  // Split long and short options
  for (var key in this._options) {
    if (hasOP(this._options, key)) {
      var value = this._options[key];
      var noval = (value === null || value === undefined);
      // Check for short option (single letter without value)
      if (key.length === 1 && noval) {
        short.push(key);
      }
      else {
        long.push(buildOption(key, value));
      }
    }
  }

  // Add short options if any are present
  if (short.length > 0) args.push('-' + short.join(''));

  // Add long options if any are present
  if (long.length > 0)  args.push(long.join(' '));

  // Add includes/excludes in order
  this._patterns.forEach(function (def) {
    if (def.action === '-') {
      args.push(buildOption('exclude', def.pattern));
    }
    else if (def.action === '+') {
      args.push(buildOption('include', def.pattern));
    }
    else {
      debug(this, 'Unknown pattern action ' + def.action);
    }
  });

  // Add source(s) and destination
  args.push(
    this.source().join(' '),
    this.destination()
  );

  return args;
};

/**
 * Simple hasOwnProperty wrapper. This will call hasOwnProperty on the obj
 * through the Object prototype.
 * @private
 * @param {Object} obj  The object to check the property on
 * @param {String} key  The name of the property to check
 * @return {Boolean}
 */
function hasOP(obj, key) {
  return Object.prototype.hasOwnProperty.call(obj, key);
}

/**
 * Build an option for use in a shell command.
 * @param {String} name
 * @param {String} vlaue
 * @return {String}
 */
function buildOption(name, value) {
  var single = (name.length === 1) ? true : false;

  // Decide on prefix and value glue
  var prefix = (single) ? '-' : '--';
  var glue = (single) ? ' ' : '=';

  // Build the option
  var option = prefix + name;
  if (arguments.length > 1 && value) {
    option += glue + escapeShellArg(String(value));
  }

  return option;
}

/**
 * Escape an argument for use in a shell command.
 * @param {String} arg
 * @return {String}
 */
function escapeShellArg(arg) {
  //PATCH: Removing wrong quotes
  return '' + arg.replace(/(["'`\\])/g, '\\$1') + '';
}
