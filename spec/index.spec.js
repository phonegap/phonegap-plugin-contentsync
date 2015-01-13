/*!
 * Module dependencies.
 */

var cordova = require('./helper/cordova'),
    contentSync = require('../www'),
    execSpy,
    execWin,
    options;

/*!
 * Specification.
 */

describe('phonegap-plugin-contentsync', function() {
    beforeEach(function() {
        options = { src: 'http://path/to/src.zip' };
        execSpy = spyOn(cordova.required, 'cordova/exec');
    });

    describe('.sync', function() {
        beforeEach(function() {
            execWin = jasmine.createSpy();
            execSpy.andCallFake(execWin);
        });

        it('should require the options parameter', function() {
            expect(function() {
                contentSync.sync();
            }).toThrow();
            expect(execSpy).not.toHaveBeenCalled();
        });

        it('should require the options.src parameter', function() {
            expect(function(){
                contentSync.sync({ nimbly: 'bimbly' });
            }).toThrow();
            expect(execSpy).not.toHaveBeenCalled();
        });

        it('should return an instance of ContentSync', function() {
            var sync = contentSync.sync(options);
            expect(sync).toEqual(jasmine.any(contentSync.ContentSync));
        });

        it('should delegate to cordova.exec', function(done) {
            contentSync.sync(options);
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

        describe('when cordova.exec called', function() {
            it('should default options.type to "replace"', function(done) {
                contentSync.sync(options);
                setTimeout(function() {
                    expect(execSpy).toHaveBeenCalledWith(
                        jasmine.any(Function),
                        null,
                        'Sync',
                        'sync',
                        [options.src, 'replace']
                    );
                    done();
                }, 100);
            });

            it('should set options.type to whatever we specify', function(done) {
                options.type = 'superduper';
                contentSync.sync(options);
                setTimeout(function() {
                    expect(execSpy).toHaveBeenCalledWith(
                        jasmine.any(Function),
                        null,
                        'Sync',
                        'sync',
                        [options.src, 'superduper']
                    );
                    done();
                }, 100);
            });

            // @FIX this does not test the scenario
            //
            // The success callback should have a deeper set of tests under
            // a describe block. It should tests the various states that a sync
            // will go through:
            //   - continuous progress
            //   - complete event
            //
            // Additionally, we should have an error callback block which tests
            // the two error states:
            //   - an error occured
            //   - sync cancelled internally
            it('should fire the success callback with a return value', function(done) {
                contentSync.sync(options);
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
        });
    });

    describe('.cancel', function() {
        it('should delegate to exec', function(done) {
            var sync = contentSync.sync(options);
            sync.cancel();
            setTimeout(function() {
                expect(execSpy).toHaveBeenCalled();
                expect(execSpy.callCount).toEqual(2);
                expect(execSpy.mostRecentCall.args).toEqual(
                    [jasmine.any(Function), null, 'Sync', 'cancel', []]
                );
                done();
            }, 100);
        });
    });

    describe('.on', function() {
        it('should support the event "complete"', function() {
            var sync = contentSync.sync(options);
            var completeWin = jasmine.createSpy(function() { console.log('i win'); });
            sync.on('complete', completeWin);
            sync.emit('complete');
            expect(completeWin).toHaveBeenCalled();
        });

        it('should support the event "cancel"', function() {
            var sync = contentSync.sync(options);
            var cancelCallback = jasmine.createSpy(function() { console.log('i cancel'); });
            sync.on('cancel', cancelCallback);
            sync.emit('cancel');
            expect(cancelCallback).toHaveBeenCalled();
        });

        it('should support the event "progress"', function() {
            var sync = contentSync.sync(options);
            var progressCallback = jasmine.createSpy(function() { console.log('i progress'); });
            sync.on('progress', progressCallback);
            sync.emit('progress');
            expect(progressCallback).toHaveBeenCalled();
        });

        describe('progress event', function() {
            it('should pass an argument', function() {
                var sync = contentSync.sync(options);
                var myMsg = 'this is custom';
                var progressCallback = jasmine.createSpy(function(theMsg) { return theMsg; });
                sync.on('progress', progressCallback);
                sync.emit('progress', myMsg);
                expect(progressCallback).toHaveBeenCalled();
                expect(progressCallback.mostRecentCall.args).toEqual(['this is custom']);
            });
        });

        it('should support the event "error"', function() {
            var sync = contentSync.sync(options);
            var errorCallback = jasmine.createSpy(function() { console.log('i error'); });
            sync.on('error', errorCallback);
            sync.emit('error');
            expect(errorCallback).toHaveBeenCalled();
        });
    });
});
