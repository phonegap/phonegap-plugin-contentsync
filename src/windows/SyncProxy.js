// progress-state 
// 0:stopped, 1:downloading,2:extracting,3:complete

// error-state
// 1:invalid url
// 2:connection err
// 3:unzip err


var appData = Windows.Storage.ApplicationData.current;
var FileOpts = Windows.Storage.CreationCollisionOption;
var getFolderFromPathAsync = Windows.Storage.StorageFolder.getFolderFromPathAsync;
var getFileFromPathAsync = Windows.Storage.StorageFile.getFileFromPathAsync;
var replaceExisting = Windows.Storage.NameCollisionOption.replaceExisting;
var AppPath = Windows.ApplicationModel.Package.current.installedLocation.path;

function cleanPath(pathStr) {
    return pathStr.replace(/\//g, "\\");
}

function copyAndReplaceFileFromPathAsync(path,dest) {
    return Windows.Storage.StorageFile.getFileFromPathAsync(path)
    .then(function (file) {
        return file.copyAsync(dest, file.name, Windows.Storage.NameCollisionOption.replaceExisting);
    });
}

function copyCordovaAssetsAsync(wwwFolder, destWWWFolder) {
    return getFolderFromPathAsync(wwwFolder.path + "\\plugins")
    .then(function (pluginsFolder) {
        return WinJS.Promise.join([recursiveCopyFolderAsync(pluginsFolder, destWWWFolder, null, false),
                                   copyAndReplaceFileFromPathAsync(wwwFolder.path + "\\cordova.js", destWWWFolder),
                                   copyAndReplaceFileFromPathAsync(wwwFolder.path + "\\cordova_plugins.js", destWWWFolder)]);
    });
}

// this can throw exceptions, callers responsibility
function startDownload(src, storageFile) {
    var uri = Windows.Foundation.Uri(src);
    var downloader = new Windows.Networking.BackgroundTransfer.BackgroundDownloader();
    var download = downloader.createDownload(uri, storageFile);
    return download.startAsync();
}

function recursiveCopyFolderAsync(src, dst, name, skipRoot) {
    name = name ? name : src.name;

    var getDestFolder = function () { return WinJS.Promise.wrap(dst); };
    if (!skipRoot) {
        getDestFolder = function () {
            return dst.createFolderAsync(name, FileOpts.openIfExists)
        }
    }

    return new WinJS.Promise(function (complete, failed) {
        WinJS.Promise.join({
            destFolder: getDestFolder(),
            files: src.getFilesAsync(),
            folders: src.getFoldersAsync()
        })
        .done(function (resultObj) {
            //console.log("destFolder = " + resultObj.destFolder.path);
            if (!(resultObj.files.length || resultObj.folders.length)) {
                // nothing to copy
                complete();
                return 1;
            }
            var fileCount = resultObj.files.length;
            var copyfolders = function () {
                if (!fileCount--) {
                    complete();
                    return 2;
                }
                recursiveCopyFolderAsync(resultObj.folders[fileCount], resultObj.destFolder)
                .done(function () {
                    copyfolders();
                }, failed);
            };
            var copyfiles = function () {
                if (!fileCount--) {
                    // done with files, move on to folders
                    fileCount = resultObj.folders.length;
                    copyfolders();
                    return 3;
                }
                var file = resultObj.files[fileCount];
                //console.log("copying " + file.name + " => " + resultObj.destFolder.name);
                file.copyAsync(resultObj.destFolder || dst, file.name, replaceExisting)
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

        var destFolderPath = cleanPath(id);
        var rootTempFolder = null;

        var destFolder = null;
        var destZipFile = null;
        var destWWWFolder = null;
        var fileName = id;

        if (id.indexOf("\\") > -1) {
            var pathParts = id.split("\\");
            fileName = pathParts.pop();
        }

        if (fileName.indexOf(".zip") < 0) { // todo, could be some.zip/file ...
            fileName += ".zip";
        }

        var folderExisted = false;
        function getOrCreateLocalFolder(folderPath) {
            console.log("folderPath = " + folderPath);
            return appData.localFolder.getFolderAsync(folderPath)
            .then(function (folder) {
                folderExisted = true;
                return folder;
            },
            function (err) {
                // folder does not exist, let's create it
                console.log("error: " + err.description);
                return appData.localFolder.createFolderAsync(folderPath)
                .then(function (folder) {
                    return folder;
                },
                function (err) {

                });
            });
        }

        WinJS.Promise.join({
            wwwFolder: getFolderFromPathAsync(AppPath + "\\www"),
            destFolder: getOrCreateLocalFolder(destFolderPath),
            destWWWFolder: getOrCreateLocalFolder(destFolderPath + "\\www")
        }).done(function (res) {
            if (folderExisted && type == 'local') {
                // get out of the promise chain
                cbSuccess({ 'localPath': destFolderPath, 'status': 3 }, { keepCallback: false });
            }
            else {
                destFolder = res.destFolder;
                wwwFolder = res.wwwFolder;
                destWWWFolder = res.destWWWFolder;

                var job = WinJS.Promise.wrap(null);
                if (bCopyRootApp) {
                    job = recursiveCopyFolderAsync(wwwFolder, destFolder, "www", true);
                }
                else {

                }

                job = job.then(function () {
                    return destFolder.createFileAsync(fileName, FileOpts.replaceExisting).then(function (storageFile) {
                        destZipFile = storageFile;
                    },
                    function (err) {
                        console.log(err);
                    });
                });
                job = job.then(function (res) {
                    try {
                        if (src) {
                            return startDownload(src, destZipFile);
                        }
                        else {
                            return false;
                        }
                    } catch (e) {
                        console.log(e.message);
                        cbFail(1); // INVALID_URL_ERR
                    }
                }).then(function downloadComplete(dlResult) { // download is done
                    if (dlResult) {
                        //console.log("download is complete " + dlResult);
                        cbSuccess({ 'progress': 50, 'status': 2 }, { keepCallback: true }); // EXTRACTING

                        return ZipWinProj.PGZipInflate.inflateAsync(dlResult.resultFile, destFolder)
                        .then(function (obj) {
                            //console.log("got a result from inflateAsync :: " + obj);
                            return true;
                        },
                        function (e) {
                            //console.log("got err from inflateAsync :: " + e);
                            cbFail(3); // UNZIP_ERR
                            return false;
                        });
                    }
                    else {
                        return false;
                    }

                },
                function (err) {   // download error
                    console.log(err);
                    cbFail(1); // INVALID_URL_ERR
                    return false;
                },
                function (progressEvent) {
                    var total = progressEvent.progress.totalBytesToReceive;
                    var bytes = progressEvent.progress.bytesReceived;
                    var progPercent = total ? Math.round(bytes / total * 50) : 0;
                    cbSuccess({ 'progress': progPercent, 'status': 1 }, { keepCallback: true });    // 0:stopped, 1:downloading, 2:extracting,  3:complete
                })
                .then(function maybeCopyCordovaAssets(res) {
                    return bCopyCordovaAssets ? copyCordovaAssetsAsync(wwwFolder, destWWWFolder) : null;
                },
                function (err) { 
                    console.log("got err  : " + err);
                })
                .then(function (boom) {
                    cbSuccess({ 'localPath': destFolder, 'status': 3 }, { keepCallback: false });
                })

            }
        },
        function (err) {
            console.log("Error: " + err.description);
            cbFail(2);
        });
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
