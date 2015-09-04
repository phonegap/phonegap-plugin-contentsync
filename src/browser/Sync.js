function notSupported() {
    console.log('ContentSync is not supported on browser platform');
}

var ContentSync = function() {};
ContentSync.prototype.on = function() {};
ContentSync.prototype.emit = function() {};
ContentSync.prototype.cancel = function() {};

function sync() {
    notSupported();
    return new ContentSync();
}

module.exports = {
    sync: sync,
    unzip: notSupported,
    download: notSupported,
    ContentSync: ContentSync
};
