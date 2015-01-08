phonegap-plugin-contentsync
===========================

Greetings fellow keyboard masher, 

This is a PhoneGap plugin that allows you to retrieve
a PhoneGap app being served from a server and as well as 
being able to easily update that app.

Note: this plugin is still pretty new so expect some changes!

## Installation
``` cordova plugin add https://github.com/phonegap/phonegap-plugin-contentsync ```

## Supported Platforms

- iOS (in the works)
- Android (in the works)
- WP8 (in the works)

## ContentSync

### Quick example:
```
var sync = ContentSync.sync( { src: 'http://myserver' } );
sync.on('complete', function(result) {
    alert('The saved content lives at: ' + result.location);
});
```

### Methods
- sync: syncs to a remote destination
- cancel: cancel the sync operation
- on: subscribe to sync events

### sync
Parameters:
- options: (Object). Valid keys:
    - src: (String) Remote destination to grab content from
    - type: (String) Sets the merge strategy for new content. Valid strings:
        - replace: This is the normal behavior. Existing content is replaced completely by the imported content, i.e. is overridden or deleted accordingly.
        - merge: Existing content is not modified, i.e. only new content is added and none is deleted or modified.
        - update: Existing content is updated, new content is added and none is deleted.

### on
Parameters:
- event: (String). Describes which event you want to subscribe to. Valid events:
    - complete: Fires when we have successfully downloaded from the source.
    - cancel: Fires when we use sync.cancel();
    - progress: Fires when the native portion begins to download the content and returns progress updates.
    - error: Fires when an error occured. 

