

exports.defineAutoTests = function() {

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
	            if(!progressEvent) {
	            	progressEvent = progress;
	            }
	        });

	        sync.on('complete', function(data) {
	        	expect(progressEvent).toBeDefined("Progress should have been received");
	        	expect(progressEvent.status).toBeDefined("Progress event should have a status prop");
	        	expect(progressEvent.progress).toBeDefined("Progress event should have a progress prop");
	        	expect(data).toBeDefined("On complete, data is not null");
	        	done();
	        });

	        sync.on('error', function(e) {
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
        });

        /*

        Tests if the local copy is at the correct place and can be accessed via file plugin.
        on android this works, as the files are copied to the PERSISTENT location:

         /data/data/<app-id>/files

        on iOS the files are copied to

         /var/mobile/Applications/<UUID>/Library  (or .../Documents in compatibility mode)

        but the persistent directory is .../Library/files.

         */
        function syncAndTest(appId, success, fail) {
            var sync = ContentSync.sync({
                id: appId,
                type: 'local',
                copyRootApp: true
            });
            sync.on('complete', function(localDataPath) {
                var file = appId + '/index.html';
                window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, function(fs) {
                    fs.root.getFile(file, {create: false}, function(fileEntry) {
                        expect(fileEntry).toBeDefined();
                        success();
                    }, function(e){
                        fail(file + ' should exist in local copy. Error code ' + e.code);
                    });
                }, fail);
            });
            sync.on('error', fail);
        }

        it('local copy is accessible via file plugin', function(done) {
            var appId = 'local/test' + (new Date()).getTime(); // create new id every time
            syncAndTest(appId, done, function(e){
                fail(e);
                done();
            })
        });

        it('create local copy with www prefix', function(done) {
            var appId = 'www/local/test' + (new Date()).getTime(); // create new id every time
            syncAndTest(appId, done, function(e){
                fail(e);
                done();
            })
        });

        it('create local copy with www suffix', function(done) {
            var appId = 'local/test' + (new Date()).getTime() + '/www'; // create new id every time
            syncAndTest(appId, done, function(e){
                fail(e);
                done();
            })
        });


    });


};

exports.defineManualTests = function() {

};
