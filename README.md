# phonegap-plugin-contentsync

Greetings fellow keyboard masher,

This is a PhoneGap plugin that allows you to retrieve
a PhoneGap app being served from a server and as well as
being able to easily update that app.

Note: this plugin is still pretty new so expect some changes!

## Installation

`phonegap plugin add https://github.com/phonegap/phonegap-plugin-contentsync`

## Supported Platforms

- iOS (in the works)
- Android (in the works)
- WP8 (in the works)

## ContentSync

### Example

```javascript
var sync = ContentSync.sync({ src: 'http://myserver' });
sync.on('complete', function(result) {
    alert('The saved content lives at: ' + result.location);
});
```

### API

#### sync(options)

Parameters:

- __options__: (Object)
    - __src__: (String) Remote destination to grab content.
    - __[type]__: (String) Sets the merge strategy for new content. Optional.
        - __replace:__ This is the normal behavior. Existing content is replaced completely by the imported content, i.e. is overridden or deleted accordingly. (Default)
        - __merge__: Existing content is not modified, i.e. only new content is added and none is deleted or modified.
        - __update__: Existing content is updated, new content is added and none is deleted.

Returns:

- Instance of `ContentSync`.

Example:

```
var sync = ContentSync.sync({ src: 'http://myserver' });
```

### ContentSync.on(event, callback)

Parameters:

- __event__: (String). Describes which event you want to subscribe to.
    - __progress__: Fires when the native portion begins to download the content and returns progress updates.
        - __data.progressLength__: (Integer) between 0 - 100.
    - __complete__: Fires when we have successfully downloaded from the source.
    - __error__: Fires when an error occured.
        - __e__: (Error) describes the error.
    - __cancel__: Fires when we use sync.cancel();
- __callback__: (Function). Triggered on the event.

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
