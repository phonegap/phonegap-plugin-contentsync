# phonegap-plugin-contentsync [![Build Status](https://travis-ci.org/phonegap/phonegap-plugin-contentsync.svg?branch=master)](https://travis-ci.org/phonegap/phonegap-plugin-contentsync) [![bitHound Score][bithound-img]][bithound-url]

> Download and cache remotely hosted zipped content bundles, unzipping automatically.

## Installation

This requires phonegap 5.0+ ( current stable v1.2.0 )

```
phonegap plugin add phonegap-plugin-contentsync
```

It is also possible to install via repo url directly ( unstable )

```
phonegap plugin add https://github.com/phonegap/phonegap-plugin-contentsync
```

## Supported Platforms

- Android
- iOS
- WP8


## Quick Example

```javascript
// Create a new instance of ContentSync pointing to zipped resource 'movie-1.zip' - note
// that the url need not end in zip - it just needs to point to something producing
// a application/octet-stream mime type
var sync = ContentSync.sync({
        src: 'https://myserver/assets/movie-1.zip',
        id: 'movie-1'
});

sync.on('progress', function(data) {
    // data.progress
});

sync.on('complete', function(data) {
    // data.localPath
});

sync.on('error', function(e) {
    // e
});

sync.on('cancel', function() {
    // triggered if event is cancelled
});
```

#### Security note:

For updating a production app using `ContentSync.sync`, **always** use HTTPS. [Other Updaters](https://sparkle-project.github.io/documentation/security/#http-mitm-vulnerability) have had vulnerabilities exposed when updating over insecure HTTP.

## API

### ContentSync.sync(options)

Parameter | Description
--------- | ------------
`options.src` | `String` URL to the remotely hosted content. For updates in production, this URL should *always* use HTTPS
`options.id` | `String` Unique identifer to reference the cached content.
`options.type` | `String` _(Optional)_ Defines the copy strategy for the cached content.<br/>The type `replace` is the default behaviour that deletes the old content and caches the new content.<br/> The type `merge` will add the new content to the existing content. This will replace existing files, add new files, but never delete files.<br/>The type `local` returns the full path to the cached content if it exists or downloads it from `options.src` if it doesn't. `options.src` is not required if cached content actually exists.
`options.headers` | `Object` _(Optional)_ Set of headers to use when requesting the remote content from `options.src`.
`options.copyCordovaAssets` | `Boolean` _(Optional)_ Copies `cordova.js`, `cordova_plugins.js` and `plugins/` to sync'd folder. This operation happens after the source content has been cached, so it will override any existing Cordova assets. Default is `false`.
`options.copyRootApp` | `Boolean` _(Optional)_ Copies the `www` folder to sync'd folder. This operation happens before the source content has been cached, then the source content is cached and finally it copies `cordova.js`, `cordova_plugins.js` and `plugins/` to sync'd folder to remain consistent with the installed plugins. Default is `false`.
`options.timeout` | `Double` _(Optional)_ Request timeout. Default is 15 seconds.
`options.trustHost` | `Boolean` _(Optional)_ Trust SSL host. Host defined in `options.src` will be trusted. Ignored if `options.src` is undefined.
`options.manifest` | `String` _(Optional)_ If specified the `copyRootApp` functionality will use the list of files contained in the manifest file during it's initial copy. {Android only}
`options.validateSrc` | `Boolean` _(Optional)_ Whether to validate src url with a HEAD request before download (ios only, default true).

#### Returns

- Instance of `ContentSync`.

#### Example

```javascript
var sync = ContentSync.sync({
        src: 'https://myserver/app/1',
        id: 'app-1'
});
```

### sync.on(event, callback)

Parameter | Description
--------- | ------------
`event` | `String` Name of the event to listen to. See below for all the event names.
`callback` | `Function` is called when the event is triggered.

### sync.on('progress', callback)

The event `progress` will be triggered on each update as the native platform downloads and caches the content.

Callback Parameter | Description
------------------ | -----------
`data.progress` | `Integer` Progress percentage between `0 - 100`. The progress includes all actions required to cache the remote content locally. This is different on each platform, but often includes requesting, downloading, and extracting the cached content along with any system cleanup tasks.
`data.status` | `Integer` Enumeration of `PROGRESS_STATE` to describe the current progress state.

#### Example

```javascript
sync.on('progress', function(data) {
    // data.progress
    // data.status
});
```

### sync.on('complete', callback)

The event `complete` will be triggered when the content has been successfully cached onto the device.

Callback Parameter | Description
------------------ | -----------
`data.localPath` | `String` The file path to the cached content. The file path will be different on each platform and may be relative or absolute. However, it is guaraneteed to be a compatible reference in the browser.
`data.cached` | `Boolean` Set to `true` if options.type is set to `local` and cached content exists. Set to `false` otherwise.

#### Example

```javascript
sync.on('complete', function(data) {
    // data.localPath
    // data.cached
});
```

### sync.on('error', callback)

The event `error` will trigger when an internal error occurs and the cache is aborted.

Callback Parameter | Description
------------------ | -----------
`e.type` | `Integer` Enumeration of `ERROR_STATE` to describe the current error
`e.responseCode` | `Integer` HTTP error code if available, `-1` otherwise

#### Example

```javascript
sync.on('error', function(e) {
    // e
});
```

### sync.on('cancel', callback)

The event `cancel` will trigger when `sync.cancel` is called.

Callback Parameter | Description
------------------ | -----------
`no parameters` |

#### Example

```javascript
sync.on('cancel', function() {
    // user cancelled the sync operation
});
```

### sync.cancel()

Cancels the content sync operation and triggers the cancel callback.

```javascript
var sync = ContentSync.sync({
        src: 'https://myserver/app/1',
        id: 'app-1'
});

sync.on('cancel', function() {
    console.log('content sync was cancelled');
});

sync.cancel();
```

### ContentSync.PROGRESS_STATE

An enumeration that describes the current progress state. The mapped `String`
values can be customized for the user's app.

Integer | Description
------- | -----------
`0`     | `STOPPED`
`1`     | `DOWNLOADING`
`2`     | `EXTRACTING`
`3`     | `COMPLETE`

### ContentSync.ERROR_STATE

An enumeration that describes the received error. The mapped `String`
values can be customized for the user's app.

Error Code | Description
------------------ | -----------
`1` | `INVALID_URL_ERR`
`2` | `CONNECTION_ERR`
`3` | `UNZIP_ERR`

### ContentSync.unzip || Zip.unzip - ContentSync.download

If you are using the [Chromium Zip plugin](https://github.com/MobileChromeApps/zip) this plugin won't work for you on iOS. However, it supports the same interface so you don't have to install both.

```javascript

zip.unzip(<source zip>, <destination dir>, <callback>, [<progressCallback>]);

```

There is also an extra convenience method that can be used to download an archive

```javascript

ContentSync.download(url, headers, cb)

```

The progress events described above also apply for these methods.

#### Example

```javascript
ContentSync.PROGRESS_STATE[1] = 'Downloading the media content...';
```

### ContentSync.loadUrl (cordova-ios > 4.x with cordova-plugin-wkwebview-engine)

Use this API to load assets after extraction on **cordova-ios > 4.x** and **cordova-plugin-wkwebview-engine**. Do not use `document.location` as it probably won't work. Make sure to prefix your url with `file://`

```javascript
var sync = ContentSync.sync({
        src: 'https://myserver/app/1',
        id: 'app-1'
});

sync.on('complete', function(data) {
    ContentSync.loadUrl('file://' + data.localPath, function() {
        console.log('success');
    });
});
```

## Working with the Native File System

One of the main benefits of the content sync plugin is that it does not depend on the File or FileTransfer plugins. As a result the end user should not care where the ContentSync plugin stores it's files as long as it fills the requirements that it is private and removed when it's associated app is uninstalled.

However, if you do need to use the File plugin to navigate the data downloaded by ContentSync you can use the following code snippet to get a [DirectoryEntry](https://cordova.apache.org/docs/en/3.0.0/cordova_file_file.md.html#DirectoryEntry) for the synced content.

```javascript
var sync = ContentSync.sync({
        src: 'https://myserver/app/1',
        id: 'app-1'
});

sync.on('complete', function(data) {
    window.resolveLocalFileSystemURL("file://" + data.localPath, function(entry) {
        // entry is a DirectoryEntry object
    }, function(error) {
        console.log("Error: " + error.code);
    });
});
```

As of version 1.2.0 of the plugin the location in which the plugin stores the synched content is equivaltent to the `cordova.file.dataDirectory` path from the `cordova-plugin-file` package. This is a change from previous versions so please be aware you may need to do a full sync after upgrading to version 1.2.0.

Platform | Path
------------------ | -----------
Android | `/data/data/<app-id>/files/<options.id>`
iOS | `/var/mobile/Applications/<UUID>/Library/NoCloud/<options.id>`

## Copy Root App

The asset file system is pretty slow on Android so in order to speed up the initial copy of your app to the content sync location you can specify a manifest file on Android. The file must be in the format:

```javascript
{
    'files': [
        'img/logo.png',
        'index.html',
        'js/index.js'
   ]
}
```

and if the file is placed in your apps `www` folder you would invoke it via:

```javascript
var sync = ContentSync.sync({
        src: 'https://myserver/app/1',
        id: 'app-1',
        copyRootApp: true,
        manifest: 'manifest.json'
});
```

This results in the `copyRootApp` taking about a third of the time as when a manifest file is not specified.

## Persistence of Synced Content

Content downloaded via this plugin persists between runs of the application or reboots of the phone. The content will only be removed if the application is uninstalled or you use the File API to remove the location of the synched content.

## Native Requirements

- There should be no dependency on the existing File or FileTransfer plugins.
- The native cached file path should be uniquely identifiable with the `id` parameter. This will allow the Content Sync plugin to lookup the file path at a later time using the `id` parameter.
- The first version of the plugin assumes that all cached content is downloaded as a compressed ZIP. The native implementation must properly extract content and clean up any temporary files, such as the downloaded zip.
- The locally compiled Cordova web assets should be copied to the cached content. This includes `cordova.js`, `cordova_plugins.js`, and `plugins/**/*`.
- Multiple syncs should be supported at the same time.

## Running Tests ( static tests against source code )

```
npm test
```

## Emulator Testing

The emulator tests use cordova-paramedic and the cordova-plugin-test-framework.
To run them you will need cordova-paramedic installed.

    npm install -g cordova-paramedic
    // Then from the root of this repo
    // test ios :
    cordova-paramedic --platform ios --plugin .
    // test android :
    cordova-paramedic --platform android --plugin .

## Contributing

### Editor Config

The project uses [.editorconfig](http://editorconfig.org/) to define the coding
style of each file. We recommend that you install the Editor Config extension
for your preferred IDE.

### JSHint

The project uses [.jshint](http://jshint.com/docs) to define the JavaScript
coding conventions. Most editors now have a JSHint add-on to provide on-save
or on-edit linting.

#### Install JSHint for vim

1. Install [jshint](https://www.npmjs.com/package/jshint).
1. Install [jshint.vim](https://github.com/wookiehangover/jshint.vim).

#### Install JSHint for Sublime

1. Install [Package Control](https://packagecontrol.io/installation)
1. Restart Sublime
1. Type `CMD+SHIFT+P`
1. Type _Install Package_
1. Type _JSHint Gutter_
1. Sublime -> Preferences -> Package Settings -> JSHint Gutter
1. Set `lint_on_load` and `lint_on_save` to `true`

[travis-ci-img]: https://travis-ci.org/phonegap/phonegap-plugin-contentsync.svg?branch=master
[travis-ci-url]: http://travis-ci.org/phonegap/phonegap-plugin-contentsync
[bithound-img]: https://www.bithound.io/github/phonegap/phonegap-plugin-contentsync/badges/score.svg
[bithound-url]: https://www.bithound.io/github/phonegap/phonegap-plugin-contentsync
