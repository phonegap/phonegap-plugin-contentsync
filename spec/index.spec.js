/*!
 * Module dependencies.
 */

var cordova = require('./helper/cordova'),
    contentSync = require('../www/sync'),
    execSpy;

/*!
 * Sync specification.
 */

describe('phonegap-plugin-contentsync', function() {
    beforeEach(function() {
        // spy on any cordova.required module just like any other jasmine spy.
        execSpy = spyOn(cordova.required, 'cordova/exec');
    });

    describe('.sync', function() {
        it('should return an instance of ContentSync', function() {
            var sync = contentSync.sync({ src: 'dummySrc' });
            expect(sync).toEqual(jasmine.any(contentSync.ContentSync));
        });

        it('should delegate to exec', function() {
            var sync = contentSync.sync({ src: 'dummySrc' });
            // simple
            expect(execSpy).toHaveBeenCalled();
            // detailed
            expect(execSpy).toHaveBeenCalledWith(
                jasmine.any(Function),
                null,
                'Sync',
                'sync',
                jasmine.any(Object)
            );
        });
    });
});
