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
- __sync__: syncs to a remote destination
- __cancel__: cancels the sync operation
- __on__: subscribes to sync events

### sync
Parameters:
- __options__: (Object). Valid keys:
    - __src__: (String) Remote destination to grab content from
    - __type__: (String) Sets the merge strategy for new content. Valid strings:
        - __replace:__ This is the normal behavior. Existing content is replaced completely by the imported content, i.e. is overridden or deleted accordingly.
        - __merge__: Existing content is not modified, i.e. only new content is added and none is deleted or modified.
        - __update__: Existing content is updated, new content is added and none is deleted.

### on
Parameters:
- __event__: (String). Describes which event you want to subscribe to. Valid events:
    - __complete__: Fires when we have successfully downloaded from the source.
    - __cancel__: Fires when we use sync.cancel();
    - __progress__: Fires when the native portion begins to download the content and returns progress updates.
    - __error__: Fires when an error occured. 

