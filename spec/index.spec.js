/*!
 * Module dependencies.
 */

var cordova = require('./helper/cordova'),
    content = cordova.require('./www/sync');

/*!
 * Sync specification.
 */

describe('phonegap-plugin-contentsync', function() {
    describe('.sync', function() {
        it('should return an instance of ContentSync', function() {
            var options = { src:'dummySrc' };
            var sync = content.sync(options);

            expect(sync).toEqual(jasmine.any(content.ContentSync));
        });
    });
});
