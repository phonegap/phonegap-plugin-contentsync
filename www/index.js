/* global cordova:false */

/*!
 * Module dependencies.
 */

var exec = cordova.require('cordova/exec');

/**
 * ContentSync constructor.
 *
 * @param {Object} options to initiate a new content synchronization.
 *   @param {String} src is a URL to the content sync end-point.
 *   @param {Object} type defines the sync strategy applied to the contnet.
 *     @param {String} replace completely removes existing content then copies new content.
 *     @param {String} merge   does not modify existing content, but adds new content.
 *     @param {String} update  only updates existing content, but does not add or delete new content.
 *  @param {Object} headers are used to set the headers for when we send a request to the src URL
 *  @param {String} id is used as a unique identifier for the sync operation
 * @return {ContentSync} instance that can be monitored and cancelled.
 */

var ContentSync = function(options) {
    this._handlers = {
        'progress': [],
        'cancel': [],
        'error': [],
        'complete': []
    };

    // requires src parameter
    if (typeof options === 'undefined' || typeof options.src === 'undefined') {
        throw new Error('An options object with a src property is needed');
    }

    // define synchronization strategy
    //
    //     replace: This is the normal behavior. Existing content is replaced
    //              completely by the imported content, i.e. is overridden or
    //              deleted accordingly.
    //     merge:   Existing content is not modified, i.e. only new content is
    //              added and none is deleted or modified.
    //     update:  Existing content is updated, new content is added and none
    //              is deleted.
    //
    if (typeof options.type === 'undefined') {
        options.type = 'replace';
    }

    if (typeof options.headers === 'undefined') {
        options.headers = null;
    }

    if (typeof options.id === 'undefined') {
        options.id = null;
    }

    // triggered on update and completion
    var that = this;
    var success = function(result) {
        if (result && typeof result.progress !== 'undefined') {
            that.emit('progress', result);
        } else {
            that.emit('complete', result);
        }
    };

    //triggered on error
    var fail = function(msg) {
        var e = (typeof msg === 'string') ? new Error(msg) : msg;
        that.emit('error', e);
    };

    // wait at least one process tick to allow event subscriptions
    setTimeout(function() {
        exec(success, fail, 'Sync', 'sync', [options.src, options.type, options.headers, options.id]);
    }, 10);
};

/**
 * Cancel the Content Sync
 *
 * After successfully cancelling the content sync process, the `cancel` event
 * will be emitted.
 */

ContentSync.prototype.cancel = function() {
    var that = this;
    var onCancel = function() {
        that.emit('cancel');
    };
    setTimeout(function() {
        exec(onCancel, onCancel, 'Sync', 'cancel', []);
    }, 10);
};

/**
 * Listen for an event.
 *
 * The following events are supported:
 *
 *   - progress
 *   - cancel
 *   - error
 *   - completion
 *
 * @param {String} eventName to subscribe to.
 * @param {Function} callback trigged on the event.
 */

ContentSync.prototype.on = function(eventName, callback) {
    if (this._handlers.hasOwnProperty(eventName)) {
        this._handlers[eventName].push(callback);
    }
};

/**
 * Emit an event.
 *
 * This is intended for internal use only.
 *
 * @param {String} eventName is the event to trigger.
 * @param {*} all arguments are passed to the event listeners.
 *
 * @return {Boolean} is true when the event is trigged otherwise false.
 */

ContentSync.prototype.emit = function() {
    var args = Array.prototype.slice.call(arguments);
    var eventName = args.shift();

    if (!this._handlers.hasOwnProperty(eventName)) {
        return false;
    }

    for (var i = 0, length = this._handlers[eventName].length; i < length; i++) {
        this._handlers[eventName][i].apply(undefined,args);
    }

    return true;
};

/*!
 * Content Sync Plugin.
 */

module.exports = {
    /**
     * Synchronize the content.
     *
     * This method will instantiate a new copy of the ContentSync object
     * and start synchronizing.
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
