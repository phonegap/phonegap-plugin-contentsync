var DownloadQueue = {};

// progress-state 
// 0:stopped, 1:downloading,2:extracting,3:complete

// error-state
// 1:invalid url
// 2:connection err
// 3:unzip err

var appData = Windows.Storage.ApplicationData.current;

function cleanPath(pathStr) {
    return pathStr.replace("/", "\\");
}


var Sync = {
    sync: function (cbSuccess, cbFail, options) {

        // Note, all defaults are set in base file www/index.js
        // so we can proceed knowing these are all defined.
        // options = [ src,id,type,headers,bCopyCordovaAssets,bCopyRootApp,timeout] ;

        var src = options[0];
        var id = cleanPath(options[1]);
        var type = options[2];
        var headers = options[3];
        var bCopyCordovaAssets = options[4];
        var bCopyRootApp = options[5];
        var timeout = options[6];

        var targetPath = appData.localFolder.path + id;

        var job = Windows.Storage.StorageFolder.getFolderFromPathAsync(appData.localFolder.path);
        job.then(function (folder) {
            return folder.createFolderAsync(id, Windows.Storage.CreationCollisionOption.openIfExists);
        },
        function (err) {
            console.log(err);
        })
        // folder is created
        .then(function (res) {
            console.log(res);
            try {
                var uri = Windows.Foundation.Uri(src);
                var downloader = new Windows.Networking.BackgroundTransfer.BackgroundDownloader();
                var download = downloader.createDownload(uri, storageFile);
                return download.startAsync();
            } catch (e) {
                // so we handle this and call errorCallback
                //errorCallback(new FTErr(FTErr.INVALID_URL_ERR));
                console.log(e.message);
            }
        },
        function (err) {
            console.log(err);
        })
        .then(function (complete) { // download has begun
            console.log(complete);
        },
        function (err) {
            console.log(err);
        },
        function (progress) {
            console.log("progress");
        });
        
 
        //function (error) {
        //    // Handle non-existent directory
        //    if (error.number === -2147024894) {
        //        var parent = path.substr(0, path.lastIndexOf('\\')),
        //            folderNameToCreate = path.substr(path.lastIndexOf('\\') + 1);

        //        Windows.Storage.StorageFolder.getFolderFromPathAsync(parent).then(function(parentFolder) {
        //            parentFolder.createFolderAsync(folderNameToCreate).then(downloadCallback, fileNotFoundErrorCallback);
        //        }, fileNotFoundErrorCallback);
        //    } else {
        //        fileNotFoundErrorCallback();
        //    }
        //}



        // to pass progress events, call onSuccess with {progress:0-100,status:state}

        // to complete, call onSuccess with {localPath:"...",cached:boolean}

        // on error, call error callback with an integer:ERROR_STATE



    },
    cancel: function (cbSuccess, cbFail, options) {
        var id = options.id;
        if (DownloadQueue[id]) {

            var downloadJob = DownloadQueue[id];
            if (!downloadJob.isCancelled) { // prevent multiple callbacks for the same cancel
                downloadJob.isCancelled = true;
                if (!downloadJob.request) {
                    // todo: abort it
                }
                DownloadQueue[id] = null;
            }
            cbSuccess();
        }
        else {
            // TODO: error, id not found
            cbFail();
        }
    },
    download: function (cbSuccess, cbFail, options) {
        var url = options[0];
        var unknown = options[1];
        var headers = options[2];
    },
    unzip: function (cbSuccess, cbFail, options) {
        var srcUrl = options[0];
        var destUrl = options[1];
    }
};



require("cordova/exec/proxy").add("Sync", Sync);
require("cordova/exec/proxy").add("Zip", Sync);


