function notSupported() {
    console.log('ContentSync is not supported on browser platform');
}

var ContentSync = function() {};
ContentSync.prototype.on = function() { notSupported(); };
ContentSync.prototype.emit = function() { notSupported(); };
ContentSync.prototype.cancel = function() { notSupported(); };

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
