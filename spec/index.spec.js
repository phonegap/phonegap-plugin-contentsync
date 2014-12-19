/*!
 * Module dependencies.
 */

var cordova = require('./helper/cordova'),
    contentSync = require('../www/sync'),
    execSpy,
    execWin;

/*!
 * Sync specification.
 */

describe('phonegap-plugin-contentsync', function() {
    describe('.sync', function() {
        beforeEach(function() {
            execWin = jasmine.createSpy(function() { return { result : { progressLength: 1} } });
            execSpy = spyOn(cordova.required, 'cordova/exec').andCallFake(execWin);
        });

        it('should return an instance of ContentSync', function() {
            var sync = contentSync.sync({ src: 'dummySrc' });
            expect(sync).toEqual(jasmine.any(contentSync.ContentSync));
        });

        it('should delegate to exec', function() {
            var sync = contentSync.sync({ src: 'dummySrc' });

            expect(execSpy).toHaveBeenCalled();
            expect(execSpy).toHaveBeenCalledWith(
                jasmine.any(Function),
                null,
                'Sync',
                'sync',
                jasmine.any(Object)
            );
        });

        it('should fire the success callback with a return value', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });
            expect(execWin).toHaveBeenCalled();
            expect(execSpy).toHaveBeenCalledWith(
                jasmine.any(Function),
                null,
                'Sync',
                'sync',
                jasmine.any(Object)
            );

        });

        it('should set options.type to "replace" by default', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });
            expect(execSpy).toHaveBeenCalledWith(
                jasmine.any(Function),
                null,
                'Sync',
                'sync',
                ['dummySrc', 'replace']
            );
        });

        it('should set options.type to whatever we specify', function(){
            var sync = contentSync.sync({ src: 'dummySrc', type: 'superduper' });
            expect(execSpy).toHaveBeenCalledWith(
                jasmine.any(Function),
                null,
                'Sync',
                'sync',
                ['dummySrc', 'superduper']
            );
        });

        it('should throw an error when provided with no options and not call exec', function(){
            expect(function(){ contentSync.sync(); }).toThrow(new Error('An options object with a src property is needed'));
            expect(execSpy).not.toHaveBeenCalled();
        });

        it('should throw an error when provided with no options.src and not call exec', function(){
            expect(function(){ contentSync.sync( { nimbly: 'bimbly' } ); }).toThrow(new Error('An options object with a src property is needed'));
            expect(execSpy).not.toHaveBeenCalled();
        });
    });

    describe('.cancel', function(){
         beforeEach(function() {
            execSpy = spyOn(cordova.required, 'cordova/exec');
        });

        it('should delegate to exec', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });
            sync.cancel();
            expect(execSpy).toHaveBeenCalled();
            expect(execSpy.callCount).toEqual(2);
            expect(execSpy.mostRecentCall.args).toEqual(
                [ null, null, 'Sync', 'cancel', [] ]
            );
        });
    });

    describe('.on', function(){
        beforeEach(function() {
            execWin = jasmine.createSpy(function() { return { result : { progressLength: 1} } });
            execSpy = spyOn(cordova.required, 'cordova/exec').andCallFake(execWin);
        });
        
        it('should fire the publish the complete event when sync is complete', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });   
            var completeWin = function(){ console.log('i win') };
            //sync.on('complete', completeWin);
            //expect(completeWin).toHaveBeenCalled();
        });
    });
});
