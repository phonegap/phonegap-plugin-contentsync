/*!
 * Module dependencies.
 */

var cordova = require('./helper/cordova'),
    content = cordova.require('./www/index');

/*!
 * Sync specification.
 */

describe('phonegap-plugin-contentsync', function() {
    describe('.sync', function() {
        it('should return an instance of ContentSync', function() {
            var sync = content.sync();
            expect(sync).toEqual(jasmine.any(content.ContentSync));
        });
    });
});
