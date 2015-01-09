/*!
 * Module dependencies.
 */

var cordova = require('./helper/cordova'),
    contentSync = require('../www'),
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

        it('should delegate to exec', function(done) {
            var sync = contentSync.sync({ src: 'dummySrc' });
            setTimeout(function() {
                expect(execSpy).toHaveBeenCalled();
                expect(execSpy).toHaveBeenCalledWith(
                    jasmine.any(Function),
                    null,
                    'Sync',
                    'sync',
                    jasmine.any(Object)
                );
                done();
            }, 100);
        });

        it('should fire the success callback with a return value', function(done){
            var sync = contentSync.sync({ src: 'dummySrc' });
            setTimeout(function() {
                expect(execWin).toHaveBeenCalled();
                expect(execSpy).toHaveBeenCalledWith(
                    jasmine.any(Function),
                    null,
                    'Sync',
                    'sync',
                    jasmine.any(Object)
                );
                done();
            }, 100);
        });

        it('should set options.type to "replace" by default', function(done){
            var sync = contentSync.sync({ src: 'dummySrc' });
            setTimeout(function() {
                expect(execSpy).toHaveBeenCalledWith(
                    jasmine.any(Function),
                    null,
                    'Sync',
                    'sync',
                    ['dummySrc', 'replace']
                );
                done();
            }, 100);
        });

        it('should set options.type to whatever we specify', function(done){
            var sync = contentSync.sync({ src: 'dummySrc', type: 'superduper' });
            setTimeout(function() {
                expect(execSpy).toHaveBeenCalledWith(
                    jasmine.any(Function),
                    null,
                    'Sync',
                    'sync',
                    ['dummySrc', 'superduper']
                );
                done();
            }, 100);
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

        it('should delegate to exec', function(done){
            var sync = contentSync.sync({ src: 'dummySrc' });
            sync.cancel();
            setTimeout(function() {
                expect(execSpy).toHaveBeenCalled();
                expect(execSpy.callCount).toEqual(2);
                expect(execSpy.mostRecentCall.args).toEqual(
                    [ jasmine.any(Function), null, 'Sync', 'cancel', [] ]
                );
                done();
            }, 100);
        });
    });

    describe('.on', function(){
        beforeEach(function() {
            execSpy = spyOn(cordova.required, 'cordova/exec');
        });
        
        it('should fire the complete callback when we publish it', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });
            var completeWin = jasmine.createSpy(function() { console.log('i win') });
            sync.on('complete', completeWin);
            sync.publish('complete');
            expect(completeWin).toHaveBeenCalled();
        });

        it('should fire the cancel callback when we publish it', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });
            var cancelCallback = jasmine.createSpy(function() { console.log('i cancel') });
            sync.on('cancel', cancelCallback);
            sync.publish('cancel');
            expect(cancelCallback).toHaveBeenCalled();
        });

        it('should fire the progress callback when we publish it', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });
            var progressCallback = jasmine.createSpy(function() { console.log('i progress') });
            sync.on('progress', progressCallback);
            sync.publish('progress');
            expect(progressCallback).toHaveBeenCalled();
        });

        it('should fire the progress callback with an argument when we publish it with an argument', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });
            var myMsg = 'this is custom';
            var progressCallback = jasmine.createSpy(function( theMsg ) { return theMsg; });
            sync.on('progress', progressCallback);
            sync.publish('progress', myMsg);
            expect(progressCallback).toHaveBeenCalled();
            expect(progressCallback.mostRecentCall.args).toEqual( ['this is custom'] );
        });

        it('should fire the error callback when we publish it', function(){
            var sync = contentSync.sync({ src: 'dummySrc' });
            var errorCallback = jasmine.createSpy(function() { console.log('i error') });
            sync.on('error', errorCallback);
            sync.publish('error');
            expect(errorCallback).toHaveBeenCalled();
        });
    });
});
