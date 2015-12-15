// progress-state 
// 0:stopped, 1:downloading,2:extracting,3:complete

// error-state
// 1:invalid url
// 2:connection err
// 3:unzip err

var appData = Windows.Storage.ApplicationData.current;
var FileOpts = Windows.Storage.CreationCollisionOption;
var getFolderFromPathAsync = Windows.Storage.StorageFolder.getFolderFromPathAsync;

function cleanPath(pathStr) {
    return pathStr.replace(/\//g, "\\");
}

function copyRootApp(destPath) {

}

function copyCordovaAssets(destPath) {

}

// this can throw exceptions, callers responsibility
function startDownload(src, storageFile) {
    var uri = Windows.Foundation.Uri(src);
    var downloader = new Windows.Networking.BackgroundTransfer.BackgroundDownloader();
    var download = downloader.createDownload(uri, storageFile);
    return download.startAsync();
}

function copyFolderAsync(src, dst, name) {
    console.log("copyFolderAsync :: " + src.name + " => " + dst.name);
    name = name ? name : src.name;
    return new WinJS.Promise(function (complete, failed) {
        WinJS.Promise.join({
            destFolder: dst.createFolderAsync(name, FileOpts.openIfExists),
            files: src.getFilesAsync(),
            folders: src.getFoldersAsync()
        })
        .done(function (resultObj) {
            if (!(resultObj.files.length || resultObj.folders.length)) {
                // nothing to copy
                complete();
                return;
            }
            var fileCount = resultObj.files.length;
            var copyfolders = function () {
                if (!fileCount--) {
                    complete();
                    return;
                }
                copyFolderAsync(resultObj.folders[fileCount], dst)
                .done(function () {
                    copyfolders();
                }, failed);
            };
            var copyfiles = function () {
                if (!fileCount--) {
                    // done with files, move on to folders
                    fileCount = resultObj.folders.length;
                    copyfolders();
                    return;
                }
                var file = resultObj.files[fileCount];
                console.log("copying " + file.name + " => " + resultObj.destFolder.name);
                file.copyAsync(resultObj.destFolder)
                .done(function () {
                    copyfiles();
                }, failed);
            };

            copyfiles();
        },
        failed);
    });
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
        var trustHost = options[7];
        var manifest = options[8];

        var destFolder = null;

        if (type == "local") {
            // just check if the file exists, and return it's path if it does
            id = options[1];
        }
        
        var fileName = id;

        var subFolder = null;
        if (id.indexOf("\\") > -1) {
            var pathParts = id.split("\\");
            fileName = pathParts.pop();
            subFolder = pathParts.join("\\");
        }

        if (fileName.indexOf(".zip") < 0) { // todo, could be some.zip/file ...
            fileName += ".zip";
        }

        var job = getFolderFromPathAsync(appData.localFolder.path);
        if (subFolder) {
            job = job.then(function (folder) {
                return folder.createFolderAsync(subFolder, FileOpts.openIfExists);
            },
            function (err) {
                console.log(err);
            });
        }
        // folder was created if need be
        job.then(function (folder) {
            destFolder = folder; // hmm, should be someDir/myDir when given someDir.myDir.zip aka fileName minus .zip
            return folder.createFileAsync(fileName, FileOpts.replaceExisting);
        })
        // get www/ folder
        .then(function (storageFile) {
            console.log('doCopyCordovaAssets ' + storageFile.name);
            var root = Windows.ApplicationModel.Package.current.installedLocation.path;
            var path = root + "\\www";
            return getFolderFromPathAsync(path);
        })
        .then(function (wwwFolder) {
            return copyFolderAsync(wwwFolder, destFolder);
        })
        // download
        .then(function () {
            try {
                if (src) {
                    return startDownload(src, storageFile);
                }
                else {
                    return false;
                }
            } catch (e) {
                // so we handle this and call errorCallback
                //errorCallback(new FTErr(FTErr.INVALID_URL_ERR));
                console.log(e.message);
                cbFail(1); // INVALID_URL_ERR
            }
        },
        function (err) {
            //console.log(err);
            cbFail(1); // INVALID_URL_ERR
        })
        .then(function downloadComplete(dlResult) { // download is done
            if (dlResult) {
                console.log("download is complete " + dlResult);
                cbSuccess({ 'progress': 50, 'status': 2 }, { keepCallback: true }); // EXTRACTING

                return ZipWinProj.PGZipInflate.inflateAsync(dlResult.resultFile, destFolder)
                .then(function (obj) {
                    console.log("got a result from inflateAsync :: " + obj);
                    
                    return true;
                },
                function (e) {
                    console.log("got err from inflateAsync :: " + e);
                    cbFail(3); // UNZIP_ERR
                    return false;
                });
            }
            else {
                return false;
            }

        },
        function (err) {   // download error
            //console.log(err);
            cbFail(1); // INVALID_URL_ERR
            return false;
        },
        function (progressEvent) {
            var total = progressEvent.progress.totalBytesToReceive;
            var bytes = progressEvent.progress.bytesReceived;
            var progPercent = Math.round(bytes / total * 50);
            console.log("progPercent =  " + progPercent);
            cbSuccess({ 'progress': progPercent, 'status': 1 }, { keepCallback: true });    // 0:stopped, 1:downloading, 2:extracting,  3:complete
        })
        .then(function () {
            cbSuccess({ 'localPath': destFolder, 'status': 3 }, { keepCallback: false });
        })
        //.then(function doCopyCordovaAssets(res) {
        //    //.then(function (wwwFolder) {
        //    //    console.log('wwwFolder = ' + wwwFolder);
        //    //    Windows.Storage.StorageFile.getFileFromPathAsync(path + "\\index.html")
        //    //    .then(function (file) {
        //    //        return file.copyAsync(wwwFolder, file.name, Windows.Storage.NameCollisionOption.replaceExisting);

        //    //    });
        //    //});

        //    //cbSuccess({ 'localPath': destFolder, 'status': 3 }, { keepCallback: false });
        //},
        //function (err) { 
        //    console.log("got err  : " + err);
        //});
        
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
