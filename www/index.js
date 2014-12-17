/*!
 * Module dependencies.
 */

var exec = cordova.require('cordova/exec');

/**
 * ContentSync Object
 */

var ContentSync = function(options) {
};

/**
 * ContentSync::cancel
 */

ContentSync.prototype.cancel = function() {
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

