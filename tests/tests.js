

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
                fail(e);
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
            });

            sync.on('error', function(e) {
                expect(e).toBeDefined('error should be reported');
                done();
            });
        });

        it('creates local copy', function(done) {
            var sync = ContentSync.sync({
                id: 'local/test' + (new Date()).getTime(), // create new id every time
                type: 'local',
                copyRootApp: true
            });
            sync.on('complete', function(localDataPath) {
                expect(localDataPath).toBeDefined('Complete should report a data path');
                expect(localDataPath).not.toBe('');
                done();
            });
            sync.on('error', function(e) {
                fail(e);
            });
        });

        it('local w/o copy and source to fail', function(done) {
            var sync = ContentSync.sync({
                id: 'local/test' + (new Date()).getTime(), // create new id every time
                type: 'local'
            });
            sync.on('complete', function() {
                fail('because there is nothing to copy.');
            });
            sync.on('error', function(e) {
                expect(e).toBeDefined('error should report a reason.');
                done();
            });
        });
    });

};

exports.defineManualTests = function() {

};
