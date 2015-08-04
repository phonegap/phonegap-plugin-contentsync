

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
    });

}

exports.defineManualTests = function() {

}
