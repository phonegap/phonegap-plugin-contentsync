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
    - src: Sets the remote destination to grab content from
    - type: Set the merge strategy for new content
        - replace:
        - merge:
        - update:


 
