/*!
 * Module dependencies.
 */

var path = require('path');

/**
 * Cordova Require.
 *
 * Loads a cordova module by mocking the cordova require
 * implementation and returning the cordova module as a
 * node module.
 *
 * @param {String} modulePath is the path to the cordova module.
 * @return {Object} that represents the cordova module.
 */

module.exports.require = function(modulePath) {
    modulePath = path.resolve(modulePath) + '.js';

    if (!global.cordova) {
        global.cordova = {
            require: function() {
            }
        };
    }

    return require(modulePath);
};
