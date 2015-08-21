

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

	console.log("cordova.platformId = " + cordova.platformId); 
	console.log("ZipWinProj = " + ZipWinProj);


	if(cordova.platformId == 'windows') {
		describe('phonegap-plugin-contentsync windows tests', function() {
			it("Has linked C# code", function(done){
				//
				expect(ZipWinProj).toBeDefined("ZipWinProj should exist");
				expect(ZipWinProj.PGZipInflate).toBeDefined("ZipWinProj.PGZipInflate should exist");
				expect(ZipWinProj.PGZipInflate.InflateAsync).toBeDefined("ZipWinProj.PGZipInflate.InflateAsync should exist");
	        	done();
			});

		});
	}




}

exports.defineManualTests = function() {

}
