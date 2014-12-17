/*!
 * Module dependencies.
 */

var exec = cordova.require('cordova/exec');

/**
 * ContentSync Object
 */

var ContentSync = function(options) {
    var _handlers = {
        'progress' : [],
        'cancel' : [],
        'error' : [],
        'complete' :[]
    };

    if(!options.src){
        // error out - need src
    }

    if (typeof options.type == 'undefined'){
        // options.type = replace : This is the normal behavior. Existing content is replaced completely by the imported content, i.e. is overridden or deleted accordingly.
        // options.type = merge : Existing content is not modified, i.e. only new content is added and none is deleted or modified.
        // options.type = update : Existing content is updated, new content is added and none is deleted.
        options.type = 'replace';
    }

    var win = function(result){
        if(typeof result.progressLength != 'undefined'){
            this.publish('progress', result.progressLength);
        }else{
            this.publish('complete');
        }
    }

    exec(win, null, "Sync", "sync", [options.src, options.type]);
};

/**
 * ContentSync::cancel
 */

ContentSync.prototype.cancel = function() {
    exec(null, null, 'Sync', 'cancel', []);
};

/**
 * ContentSync::on
 */

ContentSync.prototype.on = function(event, callback){
    if(this._handlers.hasOwnProperty(event)){
        this._handlers[event].push(callback);
    }
};

/**
 * ContentSync::publish
 */

ContentSync.prototype.publish = function(){
    var args = Array.prototype.slice.call( arguments );
    var theEvent = args.shift();

    if(!this._handlers.hasOwnProperty(theEvent)){
        return false;
    }

    for(var i = 0,len = this._handlers[theEvent].length;i<len;i++){
        this._handlers[theEvent][i].apply(undefined,args);
    }

    return true;
};

/*!
 * Content Sync Plugin.
 */

module.exports = {
    /**
     * Run a Synchronize Task.
     *
     * @param {Object} options
     * @return {ContentSync} instance
     */

    sync: function(options) {
        return new ContentSync(options);
    },

    /**
     * ContentSync Object.
     *
     * Expose the ContentSync object for direct use
     * and testing. Typically, you should use the
     * .sync helper method.
     */

    ContentSync: ContentSync
};

