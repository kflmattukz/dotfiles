---
name: gjs-guide
description: Write and review GJS (GNOME JavaScript) code the way https://gjs.guide/guides/ teaches - ESM imports, style, async/await with Gio._promisify, cancellables, main-loop sources, memory management and cleanup, GObject subclassing, D-Bus, GVariant, Gio file and subprocess APIs. Use for any GJS code - GNOME Shell extensions, GTK/Adw apps, gjs scripts - whenever writing, fixing or reviewing files that import from gi:// or resource:///org/gnome/.
---

# GJS guide

Rules distilled from https://gjs.guide/guides/. Follow them when writing GJS; check them when reviewing. When a rule here and the surrounding code disagree, match the codebase and mention the difference.

## Imports and style

- ES modules only (required for GNOME Shell extensions since 45). Never the legacy `imports` object.
  ```js
  import Gio from 'gi://Gio';                                        // GI libraries
  import * as Main from 'resource:///org/gnome/shell/ui/main.js';    // Shell / resources
  import * as Util from './lib/util.js';                             // local
  ```
  Three groups (GI, resources, local), one blank line between groups.
- Pin GI versions before import when several exist: `import 'gi://Gtk?version=4.0';`.
- 4 spaces, single quotes, semicolons, ES5 trailing commas, no spaces inside braces (`{label: 'x'}`), no parens around a single arrow param.
- `const` by default, `let` only when reassigned, never `var`. `===` always.
- Files `lowerCamelCase.js`, directories lowercase, classes `PascalCase`, constants `UPPER_SNAKE_CASE`, private members `this._name`, unused args `_arg`.
- GObject properties in code use camelCase or snake_case accessors (`label.useMarkup`, `label.use_markup`); kebab-case only inside strings (`'notify::use-markup'`, `'changed::key'`).
- Pass all properties to the constructor (`new St.Label({text, style_class})`) instead of setting them afterwards: fewer notifications.
- Template strings, not `imports.format`. `Object.assign`, not `Lang.copyProperties`. Arrow functions or `.bind(this)`, not `Lang.bind`. ES classes, not `Lang.Class`.
- Logging: `console.log/debug/warn/error`, not `log()`. (`logError(e)` is fine as a `.catch(logError)` sink.)
- ESLint: `eslint:recommended`, `ecmaVersion 2022`, `sourceType: module`; errors on `no-await-in-loop`, `consistent-return`, `no-use-before-define` (functions exempt), `no-unused-vars` (ignore `^_`).

## Async

- One main loop runs everything. Never block it: no `*_sync` I/O, sync D-Bus calls or sync proxy constructors in Shell code. Use the async variant.
- Promisify once per module, on the prototype, then `await`:
  ```js
  Gio._promisify(Gio.File.prototype, 'load_contents_async');
  const [contents] = await file.load_contents_async(cancellable);
  ```
  The finish name is guessed from the async name. Pass it when they differ:
  ```js
  Gio._promisify(Gio.File.prototype, 'replace_contents_bytes_async', 'replace_contents_finish');
  Gio._promisify(Gio.DataInputStream.prototype, 'read_line_async', 'read_line_finish_utf8');
  ```
- Promisifying the same method twice is a no-op, so each module can promisify what it uses.
- Every promise needs a handler: `promise.catch(logError)` or `try/await/catch`.
- Parallel work: `await Promise.all(items.map(fn))`. Avoid `await` in loops unless order matters.
- Cancellation: pass a `Gio.Cancellable` to every async call tied to a lifetime (extension enable/disable, a widget). Cancel it in teardown and treat only CANCELLED as silent:
  ```js
  } catch (e) {
      if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
          logError(e);
  }
  ```
  A cancelled cancellable can't be reused: create a new one.
- After an `await`, the owner may have been destroyed meanwhile: re-check (`if (!this._actor) return;`) before touching it.

## Main-loop sources

- `GLib.timeout_add(prio, ms, cb)`, `GLib.timeout_add_seconds(prio, s, cb)`, `GLib.idle_add(prio, cb)` return an id. Return `GLib.SOURCE_CONTINUE` to repeat, `GLib.SOURCE_REMOVE` to stop.
- Store every id (`this._timeoutId`) and `GLib.source_remove(id)` it in teardown, then zero it. A source left behind keeps firing into destroyed objects.
- Default priority `GLib.PRIORITY_DEFAULT`; background work `GLib.PRIORITY_DEFAULT_IDLE` or `PRIORITY_LOW`.
- GIO async operations can't be removed like sources: cancel them with their cancellable.

## Memory and cleanup

- JS objects are garbage-collected; GObjects are refcounted, and a JS reference keeps a GObject alive. Containers also hold their children.
- Store everything you create and must undo: actors, handler ids, source ids, proxies, monitors (a `Gio.FileMonitor` with no reference is collected and goes silent).
- Disconnect every signal you connect: keep `const id = obj.connect(...)` and `obj.disconnect(id)` in teardown. In GNOME Shell prefer `obj.connectObject('sig', cb, this)` + `obj.disconnectObject(this)`.
- `destroy()` frees the GObject but not the JS wrapper. Null the reference afterwards, and never touch a destroyed object: it logs "has been already disposed". Typical sources: a timeout or async callback that outlives the actor.
- Closures keep everything they capture alive while connected or scheduled; avoid capturing large objects in long-lived callbacks.
- Cairo: end every draw/repaint handler with `cr.$dispose()`.
- Teardown order: cancel cancellables, remove sources, disconnect signals, destroy owned actors, null references. Make teardown safe to call twice.

## GObject subclassing

```js
export const Example = GObject.registerClass({
    GTypeName: 'Example', // only when referred to by name (e.g. GtkBuilder); default is Gjs_Example
    Properties: {
        'example-property': GObject.ParamSpec.string('example-property', null, null,
            GObject.ParamFlags.READWRITE, null),
    },
    Signals: {
        'changed': {},
        'item-added': {param_types: [GObject.TYPE_STRING]},
    },
}, class Example extends GObject.Object {
    constructor(params = {}) {
        super(params);
    }

    get example_property() {
        return this._example_property ?? null;
    }

    set example_property(value) {
        if (this.example_property === value)
            return;
        this._example_property = value;
        this.notify('example-property'); // not automatic for JS properties
    }
});
```

- Use `constructor(params = {})` + `super(params)`. `_init()` + `super._init()` is legacy (pre GJS 1.72); keep it only where the surrounding code or base class (e.g. some Shell classes) still uses it.
- ParamSpec: `boolean(…, default)`, `string(…, default)`, `int/uint/double/int64(…, min, max, default)`, `object(…, GType)`, `jsobject(…)`; variants via `GObject.param_spec_variant(…, new GLib.VariantType('as'), defaultVariant, flags)`. Flags `READABLE`, `WRITABLE`, `READWRITE`, `CONSTRUCT_ONLY`.
- Signals: `flags` (`RUN_FIRST` default, `RUN_LAST`, `RUN_CLEANUP`, `DETAILED`), `param_types`, `return_type`, `accumulator` (`FIRST_WINS`, or `TRUE_HANDLED` with a boolean return). Handlers receive the emitter first. A default handler is `on_<signal_name>()`.
- `int64` is limited to the safe-integer range (no BigInt).

## GVariant

- Build: typed helpers (`GLib.Variant.new_boolean(true)`, `new_string`, `new_uint32`, `new_strv`) or `new GLib.Variant('type', value)`. Always with `new`.
- JS arrays map to arrays and to tuples; objects map to dictionaries. Every `v` slot (e.g. values of `a{sv}`) takes a `GLib.Variant`, not a raw value.
- Unpack: `unpack()` = top level only; `deepUnpack()` = one level more (fine for `as`, `a{ss}`); `recursiveUnpack()` = everything to plain JS, losing type info (fine for read-only `a{sv}` / nested data). Typed getters (`get_string()` returns `[value, length]`) when the type is known.
- Debug with `variant.print(true)` and `get_type_string()`.
- GSettings: typed helpers for simple keys (`get_boolean`, `get_strv`...); complex keys via `get_value(key).recursiveUnpack()` and `set_value(key, new GLib.Variant('type', value))`.

## D-Bus

- Prefer high-level proxies from interface XML:
  ```js
  const Proxy = Gio.DBusProxy.makeProxyWrapper(interfaceXml);
  const proxy = new Proxy(Gio.DBus.session, 'org.example.Name', '/org/example/Path',
      (p, error) => { if (error) console.warn(error.message); }, cancellable);
  ```
  Pass the callback: without it the constructor is synchronous and blocks.
- Methods: `await proxy.MethodAsync(args)` (preferred), `MethodRemote(args, cb)`, `MethodSync()` (blocks; avoid).
- Properties are plain accessors (`proxy.Prop`; assigning writes to the bus). Watch `g-properties-changed` `(proxy, changed, invalidated)`, `changed.deepUnpack()`. `notify::g-name-owner` becoming null means the service vanished.
- D-Bus signals: `const id = proxy.connectSignal('Name', (proxy, sender, args) => …)`, `proxy.disconnectSignal(id)` in teardown.
- Low level: `await Gio.DBus.session.call(name, path, iface, method, new GLib.Variant('(…)', [...]), replyType, Gio.DBusCallFlags.NONE, -1, cancellable)`. Arguments are always a tuple (or `null`); read results with `reply.get_child_value(0)` or `recursiveUnpack()`. Raw signals: `signal_subscribe(...)` / `signal_unsubscribe(id)`.
- Strip remote errors before showing them: `if (e instanceof Gio.DBusError) Gio.DBusError.strip_remote_error(e);`.
- Names: `Gio.bus_watch_name(...)` / `Gio.bus_unwatch_name(id)`; `Gio.bus_own_name(...)` / `Gio.bus_unown_name(id)`. Export objects in `bus_acquired`. Services: `Gio.DBusExportedObject.wrapJSObject(xml, instance)`, assign `instance._impl` before `export()`, emit `emit_property_changed` / `emit_signal` yourself.
- D-Bus has no null/maybe type: use empty values.

## Files

- `Gio.File.new_for_path(GLib.build_filenamev([...]))` or `new_for_uri(uri)`; `get_child()`, `get_parent()`.
- Read: `const [bytes] = await file.load_contents_async(null)`, then `new TextDecoder().decode(bytes)`.
- Write (atomic, async): `await file.replace_contents_bytes_async(new GLib.Bytes(data), null, false, Gio.FileCreateFlags.REPLACE_DESTINATION, null)` with the custom finish name above. Not `replace_contents_async`: it risks corruption from data lifetime.
- `make_directory_with_parents()` has no async version; `make_directory_async` is not recursive.
- `copy`/`delete` don't recurse; `move` and `trash` handle directories.
- Enumerate: `for await (const info of await dir.enumerate_children_async('standard::*', Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, GLib.PRIORITY_DEFAULT, null))` (GJS 1.74+), or `next_files_async(n, …)` batches for many files.
- Monitor: keep the `dir.monitor(Gio.FileMonitorFlags.WATCH_MOVES, null)` object referenced; `connect('changed', (m, file, other, type) => …)`.

## Subprocesses

- `Gio.Subprocess`, never `GLib.spawn_*`. argv is an array; never build a shell string. For a user-given command line use `GLib.shell_parse_argv(str)` in try/catch.
  ```js
  Gio._promisify(Gio.Subprocess.prototype, 'communicate_utf8_async');
  const proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
  const [stdout, stderr] = await proc.communicate_utf8_async(null, cancellable);
  if (!proc.get_successful())
      throw new Error(stderr.trim() || `exit status ${proc.get_exit_status()}`);
  ```
- Cancelling a wait doesn't stop the process: `const id = cancellable.connect(() => proc.force_exit())`, disconnect in `finally`.
- Request a pipe in the flags before calling `get_stdin_pipe()` / `get_stdout_pipe()`. Stream long-running output through `Gio.DataInputStream` + `read_line_async`, chaining reads from the callback.
- `Gio.SubprocessLauncher` for env vars, cwd or redirects reused across spawns.

## Review checklist

1. ESM imports grouped GI / resources / local; no `imports.*`, `Lang.*`, `var`, `log()`.
2. No sync I/O, sync D-Bus or sync proxy constructors on the main thread.
3. Every promise handled; every `_async` called through a promisified method with the right finish name.
4. Every long-lived async call has a cancellable that teardown cancels.
5. Every source id stored and removed; every signal connection disconnected; every created actor destroyed and nulled.
6. Nothing touched after `destroy()`, including in callbacks that can fire after teardown.
7. GObject subclasses use `registerClass`, notify their own property changes, and declare signal parameter types.
8. GVariant built with `new` and the right type string, `v` slots wrapped, unpacked at the right depth.
9. `cr.$dispose()` at the end of every Cairo draw.

## Sources

Fetch the page when a detail isn't covered above:
- GJS: [intro](https://gjs.guide/guides/gjs/intro.html), [async](https://gjs.guide/guides/gjs/asynchronous-programming.html), [style](https://gjs.guide/guides/gjs/style-guide.html), [memory](https://gjs.guide/guides/gjs/memory-management.html)
- GLib: [GVariant](https://gjs.guide/guides/glib/gvariant.html)
- GObject: [basics](https://gjs.guide/guides/gobject/basics.html), [subclassing](https://gjs.guide/guides/gobject/subclassing.html), [interfaces](https://gjs.guide/guides/gobject/interfaces.html), [GType](https://gjs.guide/guides/gobject/gtype.html), [GValue](https://gjs.guide/guides/gobject/gvalue.html), [advanced](https://gjs.guide/guides/gobject/advanced.html)
- Gio: [D-Bus](https://gjs.guide/guides/gio/dbus.html), [files](https://gjs.guide/guides/gio/file-operations.html), [subprocesses](https://gjs.guide/guides/gio/subprocesses.html), [list models](https://gjs.guide/guides/gio/list-models.html), [actions and menus](https://gjs.guide/guides/gio/actions-and-menus.html)
- GTK 3 tutorial: https://gjs.guide/guides/gtk/3/ (legacy; new UIs use GTK 4 / libadwaita)
- Shell extensions (separate section): https://gjs.guide/extensions/
