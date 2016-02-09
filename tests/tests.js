exports.defineAutoTests = function() {

jasmine.DEFAULT_TIMEOUT_INTERVAL = 30000;

    describe('phonegap-plugin-contentsync', function() {

        it("should exist", function() {
            expect(window.ContentSync).toBeDefined();
            expect(typeof window.ContentSync.sync == 'function').toBe(true);
            expect(typeof window.ContentSync.download == 'function').toBe(true);
            expect(typeof window.ContentSync.unzip == 'function').toBe(true);
        });



        it("can sync", function(done){

            var progressEvent = null;
            var url = "https://github.com/timkim/zipTest/archive/master.zip";
            var sync = ContentSync.sync({ src: url, id: 'myapps/myapp', type: 'replace', copyCordovaAssets: false, headers: false });

            sync.on('progress', function(progress) {
                //console.log("in progress callback " + Object.getOwnPropertyNames(progress));
                console.log("onProgress :: " + progress.progress + " status = " + progress.status);
                if(!progressEvent) {
                    progressEvent = progress;
                }
            });

            sync.on('complete', function(data) {
                console.log("progress = " + progressEvent);
                expect(progressEvent).toBeDefined("Progress should have been received");

                console.log("progressEvent.status = " + progressEvent.status);
                expect(progressEvent.status).toBeDefined("Progress event should have a status prop");

                expect(progressEvent.progress).toBeDefined("Progress event should have a progress prop");
                console.log("progressEvent.progress = " + progressEvent.progress);

                console.log("data = " + data);
                expect(data).toBeDefined("On complete, data is not null");
                done();
            });

            sync.on('error', function (e) {
                expect(progressEvent).toBeDefined("Progress should have been received");
                expect(e).toBe(null, "Error callback was called :: " + e);
                console.log("got error back :: " + e);
                done();
            });

        }, 60000); // wait a full 60 secs

        it('reports error on 404', function(done){
            var sync = ContentSync.sync({
                src: 'https://www.google.com/error/not/found.zip',
                id: 'test' + (new Date().getTime()), // ensure that repeated tests work
                type: 'replace',
                copyCordovaAssets: false
            });
            sync.on('complete', function() {
                fail('404 page should not complete');
                done();
            });

            sync.on('error', function(e) {
                expect(e).toBeDefined('error should be reported');
                done();
            });
        }, 60000); // wait a full 60 secs for slow Android emulator

        /**
         * Helper function that tests if the file at the given path exists
         */
        function testFileExists(path, success, fail) {
            var filePath;
            if (path.indexOf('file://') === 0) {
                // test via system url
                filePath = path;
            } else {
                // test via cordova.file.dataDirectory location
                filePath = cordova.file.dataDirectory + '/' + path;
            }
            window.resolveLocalFileSystemURL(filePath, function(fileEntry) {
                expect(fileEntry).toBeDefined();
                success();
            }, function(e){
                fail(path + ' should exist in local copy. Error code ' + e.code);
            });
        }

        /**
         * Helper function that syncs and test if the local copy has the `/index.html`
         */
        function syncAndTest(appId, useLocalPath, success, fail) {
            var sync = ContentSync.sync({
                id: appId,
                type: 'local',
                copyRootApp: true
            });
            sync.on('complete', function (data) {
                if (useLocalPath && cordova.platformId !== 'windows') {
                    testFileExists('file://' + data.localPath + '/index.html', success, fail);
                } else {
                    testFileExists(appId + '/index.html', success, fail);
                }
            });
            sync.on('error', function (e) {
                fail();
            });
        }

        /**
         * Tests if the local copy is at the correct place and can be accessed via file plugin.
         */
        it('local copy is accessible via file plugin', function(done) {
            var appId = 'test' + (new Date()).getTime(); // create new id every time
            syncAndTest(appId, false, done, function(e){
                fail(e);
                done();
            })
        }, 60000); // wait a full 60 secs for slow Android emulator

        it('create local copy with www prefix', function(done) {
            var appId = 'www/local/test' + (new Date()).getTime(); // create new id every time
            syncAndTest(appId, true, done, function(e){
                fail(e);
                done();
            })
        }, 60000); // wait a full 60 secs for slow Android emulator

        it('create local copy with www suffix', function(done) {
            var appId = 'local/test' + (new Date()).getTime() + '/www'; // create new id every time
            syncAndTest(appId, true, done, function(e){
                fail(e);
                done();
            })
        }, 60000); // wait a full 60 secs for slow Android emulator

        /**
         * Test for invalid server name
         */
        it('error on invalid server name', function(done) {
            var sync = ContentSync.sync({
                src: 'http://servername',
                id: 'test' + (new Date().getTime()), // ensure that repeated tests work
                type: 'replace',
                copyCordovaAssets: false
            });
            sync.on('complete', function() {
                fail('invalid server name should not complete');
                done();
            });

            sync.on('error', function(e) {
                expect(e).toBeDefined('error should be reported');
                done();
            });
        });

    });


    if(cordova.platformId == 'windows') {
        describe('phonegap-plugin-contentsync windows tests', function() {
            it("Has linked C# code", function(done){
                //
                expect(ZipWinProj).toBeDefined("ZipWinProj should exist");
                expect(ZipWinProj.PGZipInflate)
                    .toBeDefined("ZipWinProj.PGZipInflate should exist");
                expect(ZipWinProj.PGZipInflate.inflateAsync)
                    .toBeDefined("ZipWinProj.PGZipInflate.inflateAsync should exist");
                done();
            });

        });
    }
};

exports.defineManualTests = function() {

};
