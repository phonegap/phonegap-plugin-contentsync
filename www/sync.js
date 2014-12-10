var exec = require('cordova/exec');

var sync = function(options){
	if(!options.src){
		// error out - need src
	}

	if (typeof options.type == 'undefined')){
		// options.type = replace : This is the normal behavior. Existing content is replaced completely by the imported content, i.e. is overridden or deleted accordingly.
		// options.type = merge : Existing content is not modified, i.e. only new content is added and none is deleted or modified.
		// options.type = update : Existing content is updated, new content is added and none is deleted.
		options.type = 'replace';
	}

	exec(null, null, "Sync", "sync", [src, type]);
};

module.exports = sync;