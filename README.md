# Aseprite Extensions

A collection of extensions for Aseprite to enhance my pixel art workflow, used for [my games](https://slowrush.dev) (who am I kidding? I only have the one).

To build all extensions, run `./build-all.sh`; extensions will be output to `target/`, and they can be installed into Aseprite via `Edit >> Preferences >> Extensions >> Add Extension`.

To hack on an extension without having to repeatedly repackage and reinstall it, install the extension and then run `./devlink-all.sh`; that script will symlink each extension's files to `$HOME/.config/aseprite/extensions/$extension-name/` if that directory exists. Aseprite doesn't formally support this but, hey, it seems to work - or at least, it works on Linux.

## Hotspot Palette

It's often necessary to associate various locations with sprites, such as hit
boxes, projectile spawn locations, raycast origins, animation pivots, etc.

You could hardcode the locations in your code (but it's annoying to get the offsets perfect), or you could use (or write) an editor for your game that lets you associate those locations with your sprites (more work). Both options are unpleasant if those hotspots need to move around as a result of animations.

This extension provides a third way:

* you draw the locations directly as special-colored pixels in your Aseprite sprites.
* your game's sprite loading code is responsible for finding the special pixels and interpreting them in whatever way you see fit.
* this extension lets you associate a name with each special color of pixels, and that association is stored in the "userdata" of the sprite.

For example:

* go to `Sprite >> Hotspot Palette` to define hot spots like "eyes" == ff0000 (red), hitbox = 0000ff (blue).
* you draw those colors onto a separate layer in your sprite (the name is up to you - whatever you write your sprite loading code to expect)
* this extension will add a palette picker that makes it easy to select those colors as either your foreground or background color.
* this extension will save the following userdata (viewable via `Sprite >> Properties` menu):
  * `{"hotspots": [{"color": "ff0000", "name": "eyes"}, {"color": "0000ff", "name": "hitbox"}]}`
  * only the `hotspots` object key is used by this extension; other object keys are free to be used by you for anything else.

Caveats:

* Sprite userdata must be empty or a valid JSON object.
* Only up to 10 different types of hotspot are supported.

See also:
* https://github.com/balldrix/aseprite_hitbox_data_exporter - a layer per hotspot type and then generates json output for you
* abandoned:
  * the Aseprite devs have some intention to implement this [as a first-class thing](https://github.com/aseprite/aseprite/issues/722) (but it has been about 8 years so maybe don't hold your breath).
  * https://github.com/kaiiboraka/Aseprite_Hitbox_Editor

## License

MIT
