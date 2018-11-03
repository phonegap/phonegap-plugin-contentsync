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
        options = { src: 'http://path/to/src.zip', id: 'app-1' };
        execWin = jasmine.createSpy();
        execSpy = spyOn(cordova.required, 'cordova/exec').and.callFake(execWin);
    });

    describe('.sync', function() {
        it('should require the options parameter', function() {
            expect(function() {
                options = undefined;
                contentSync.sync(options);
            }).toThrow();
            expect(execSpy).not.toHaveBeenCalled();
        });

        it('should require the options.src parameter for merge/replace', function() {
            expect(function() {
                options.src = undefined;
                contentSync.sync(options);
            }).toThrow();
            expect(execSpy).not.toHaveBeenCalled();
        });

        it('should not require the options.src parameter for local', function() {
            expect(function() {
                options.src = undefined;
                options.src = "local";
                contentSync.sync(options);
            }).not.toThrow();
            expect(execSpy).not.toHaveBeenCalled();
        });

        it('should require the options.id parameter', function() {
            expect(function() {
                options.id = undefined;
                contentSync.sync(options);
            }).toThrow();
            expect(execSpy).not.toHaveBeenCalled();
        });

        it('should return an instance of ContentSync', function() {
            var sync = contentSync.sync(options);
            expect(sync).toEqual(jasmine.any(contentSync.ContentSync));
        });
    });

    describe('.loadUrl', function() {
      it('should raise an error if url is not provided', function() {
        expect(function() {
          contentSync.loadUrl(null);
        }).toThrow();
      });

    });

    describe('ContentSync instance', function() {
        describe('cordova.exec', function() {
            it('should call cordova.exec on next process tick', function(done) {
                contentSync.sync(options);
                setTimeout(function() {
                    expect(execSpy).toHaveBeenCalledWith(
                        jasmine.any(Function),
                        jasmine.any(Function),
                        'Sync',
                        'sync',
                        jasmine.any(Object)
                    );
                    done();
                }, 100);
            });

            describe('options.src', function() {
                it('should be passed to exec', function(done) {
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[0]).toEqual(options.src);
                        done();
                    });
                    contentSync.sync(options);
                });
            });

            describe('options.id', function() {
                it('should be passed to exec', function(done) {
                    options.id = '1234567890';
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[1]).toEqual(options.id);
                        done();
                    });
                    contentSync.sync(options);
                });
            });

            describe('options.type', function() {
                it('should default to "replace"', function(done) {
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[2]).toEqual('replace');
                        done();
                    });
                    contentSync.sync(options);
                });

                it('should be passed as whatever we specify', function(done) {
                    options.type = 'superduper';
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[2]).toEqual(options.type);
                        done();
                    });
                    contentSync.sync(options);
                });
            });

            describe('options.headers', function() {
                it('should default to null', function(done) {
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[3]).toEqual(null);
                        done();
                    });
                    contentSync.sync(options);
                });

                it('should be passed as whatever we specify', function(done) {
                    options.headers = { 'Authorization': 'SECRET_PASSWORD' };
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[3]).toEqual(options.headers);
                        done();
                    });
                    contentSync.sync(options);
                });
            });

            describe('options.copyCordovaAssets', function() {
                it('should default to false', function(done) {
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[4]).toEqual(false);
                        done();
                    });
                    contentSync.sync(options);
                });
                it('should be passed as whatever we specify', function(done) {
                    options.copyCordovaAssets = true;
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[4]).toEqual(options.copyCordovaAssets);
                        done();
                    });
                    contentSync.sync(options);
                });
            });

            describe('options.copyRootApp', function() {
                it('should default to false', function(done) {
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[5]).toEqual(false);
                        done();
                    });
                    contentSync.sync(options);
                });
                it('should be passed as whatever we specify', function(done) {
                    options.copyRootApp = true;
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[5]).toEqual(options.copyRootApp);
                        done();
                    });
                    contentSync.sync(options);
                });
            });
            describe('options.timeout', function() {
                it('should default to 15.0', function(done) {
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[6]).toEqual(15.0);
                        done();
                    });
                    contentSync.sync(options);
                });
                it('should be passed as whatever we specify', function(done) {
                    options.timeout = 30.0;
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[6]).toEqual(options.timeout);
                        done();
                    });
                    contentSync.sync(options);
                });
            });
            describe('options.trustHost', function() {
                it('should default to false', function(done) {
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[7]).toEqual(false);
                        done();
                    });
                    contentSync.sync(options);
                });
                it('should be passed as whatever we specify', function(done) {
                    options.trustHost = true;
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[7]).toEqual(options.trustHost);
                        done();
                    });
                    contentSync.sync(options);
                });
            });
            describe('options.manifest', function() {
                it('should default to the empty string', function(done) {
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[8]).toEqual("");
                        done();
                    });
                    contentSync.sync(options);
                });
                it('should be passed as whatever we specify', function(done) {
                    options.manifest = "manifest.json";
                    execSpy.and.callFake(function(win, fail, service, id, args) {
                        expect(args[8]).toEqual(options.manifest);
                        done();
                    });
                    contentSync.sync(options);
                });
            });
        });

        describe('on "progress" event', function() {
            it('should be emitted with an argument', function(done) {
                execSpy.and.callFake(function(win, fail, service, id, args) {
                    win({ 'progress': 1 });
                });
                var sync = contentSync.sync(options);
                sync.on('progress', function(data) {
                    expect(data.progress).toEqual(1);
                    done();
                });
            });
        });

        describe('on "complete" event', function() {
            beforeEach(function() {
                execSpy.and.callFake(function(win, fail, service, id, args) {
                    win({
                        localPath: 'file:///path/to/content'
                    });
                });
            });

            it('should be emitted on success', function(done) {
                var sync = contentSync.sync(options);
                sync.on('complete', function(data) {
                    done();
                });
            });

            it('should provide the data.localPath argument', function(done) {
                var sync = contentSync.sync(options);
                sync.on('complete', function(data) {
                    expect(data.localPath).toEqual('file:///path/to/content');
                    done();
                });
            });
        });

        describe('on "error" event', function() {
            it('should be emitted with an Error', function(done) {
                execSpy.and.callFake(function(win, fail, service, id, args) {
                    fail('something went wrong');
                });
                var sync = contentSync.sync(options);
                sync.on('error', function(e) {
                    expect(e).toEqual(jasmine.any(Error));
                    expect(e.message).toEqual('something went wrong');
                    done();
                });
            });
        });

        describe('.cancel()', function() {
            it('should delegate to exec', function(done) {
                var sync = contentSync.sync(options);
                sync.cancel();
                setTimeout(function() {
                    expect(execSpy).toHaveBeenCalled();
                    expect(execSpy.calls.count()).toBe(2); // 1) sync, 2) cancel
                    expect(execSpy.calls.mostRecent().args).toEqual([
                        jasmine.any(Function),
                        jasmine.any(Function),
                        'Sync',
                        'cancel',
                        [ options.id ]
                    ]);
                    done();
                }, 100);
            });

            it('should emit the "cancel" event', function(done) {
                execSpy.and.callFake(function(win, fail, service, id, args) {
                    win();
                });
                var sync = contentSync.sync(options);
                sync.on('cancel', function() {
                    done();
                });
                sync.cancel();
            });
        });
    });

    describe('PROGRESS_STATE enumeration', function() {
        it('should defined 0 as STOPPED', function() {
            expect(contentSync.PROGRESS_STATE[0]).toEqual('STOPPED');
        });

        it('should defined 1 as DOWNLOADING', function() {
            expect(contentSync.PROGRESS_STATE[1]).toEqual('DOWNLOADING');
        });

        it('should defined 2 as EXTRACTING', function() {
            expect(contentSync.PROGRESS_STATE[2]).toEqual('EXTRACTING');
        });

        it('should defined 3 as COMPLETE', function() {
            expect(contentSync.PROGRESS_STATE[3]).toEqual('COMPLETE');
        });
    });
});
