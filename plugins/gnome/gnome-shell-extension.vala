/*
 * Copyright (c) 2016 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

using GLib;


namespace GnomePlugin
{
    private const string SCRIPT_WRAPPER = """
(function() {
    ${SCRIPT}

    return null;
})();
""";

    private const string LOAD_SCRIPT = """
const { Gio } = imports.gi;
const FileUtils = imports.misc.fileUtils;
const { ExtensionType } = imports.misc.extensionUtils;

let perUserDir = Gio.File.new_for_path(global.userdatadir);
let uuid = '${UUID}';
let extension = Main.extensionManager.lookup(uuid);

if (extension)
    return;

FileUtils.collectFromDatadirs('extensions', true, (dir, info) => {
    let fileType = info.get_file_type();
    if (fileType != Gio.FileType.DIRECTORY)
        return;

    if (info.get_name() != uuid)
        return;

    let extensionType = dir.has_prefix(perUserDir)
        ? ExtensionType.PER_USER
        : ExtensionType.SYSTEM;
    try {
        Main.extensionManager.loadExtension(
            Main.extensionManager.createExtensionObject(uuid, dir, extensionType)
        );
    } catch (error) {
        logError(error, 'Could not load extension %s'.format(uuid));
        throw error;
    }
});
extension = Main.extensionManager.lookup(uuid);
if (!extension)
    throw new Error('Could not find extension %s'.format(uuid));
""";

    private const string RELOAD_SCRIPT = """
let uuid = '${UUID}';
let extension = Main.extensionManager.lookup(uuid);

try {
    if (extension)
        Main.extensionManager.reloadExtension(extension);
    else
        throw new Error('Could not find extension %s'.format(uuid));
} catch (error) {
    logError(error, 'Error while reloading extension %s'.format(uuid));
    throw error;
}
""";


    internal errordomain GnomeShellExtensionError
    {
        SYNC_ERROR,
        EVAL_ERROR
    }


    internal class GnomeShellExtension : GLib.Object, GLib.AsyncInitable
    {
        public string                 uuid { get; construct set; }
        public string                 path { get; set; }
        public string                 version { get; set; }
        public Gnome.ExtensionState   state { get; set; default=Gnome.ExtensionState.UNINSTALLED; }

        private Gnome.Shell           shell_proxy;
        private Gnome.ShellExtensions shell_extensions_proxy;
        private ulong                 extension_state_changed_id = 0;


        public GnomeShellExtension (Gnome.Shell           shell_proxy,
                                    Gnome.ShellExtensions shell_extensions_proxy,
                                    string                uuid)
        {
            GLib.Object (uuid: uuid,
                         path: "",
                         version: "");

            this.shell_proxy = shell_proxy;
            this.shell_extensions_proxy = shell_extensions_proxy;
        }

        /**
         * Initialize D-Bus proxy and fetch extension state
         */
        public virtual async bool init_async (int          io_priority = GLib.Priority.DEFAULT,
                                              Cancellable? cancellable = null)
                                              throws GLib.Error
        {
            try {
                yield this.update (cancellable);
            }
            catch (GLib.Error error) {
                throw new GnomeShellExtensionError.SYNC_ERROR ("Unable to fetch extension state");
            }

            this.extension_state_changed_id = this.shell_extensions_proxy.extension_state_changed.connect (
                this.on_extension_state_changed);

            return true;
        }

        private void do_update (HashTable<string,Variant> data) throws GLib.Error
        {
            var extension_info = Gnome.ExtensionInfo.deserialize (this.uuid, data);

            if (
                extension_info.state != this.state ||
                extension_info.path != this.path ||
                extension_info.version != this.version
            ) {
                this.freeze_notify ();

                if (extension_info.state != Gnome.ExtensionState.UNINSTALLED)
                {
                    this.path = extension_info.path;
                    this.version = extension_info.version;
                    this.state = extension_info.state;
                }
                else {
                    this.state = extension_info.state;
                }

                this.thaw_notify ();

                this.state_changed ();
            }
        }

        // private Gnome.ExtensionState   _state = Gnome.ExtensionState.UNKNOWN;
        private Gnome.ShellExtensions? proxy = null;


        public GnomeShellExtension (string uuid) throws GLib.Error
        {
            GLib.Object (uuid: uuid);
        }

        construct
        {
            this.info = Gnome.ExtensionInfo.with_defaults (this.uuid);

            // this.info = Gnome.ExtensionInfo() {
            //     uuid = this.uuid,
            //     path = "",
            //     version = "",
            //     state = Gnome.ExtensionState.UNKNOWN
            // };
        }

        public virtual async bool init_async (int io_priority = GLib.Priority.DEFAULT,
                                              Cancellable? cancellable = null)
                                              throws GLib.Error
        {
            try {
                this.proxy = yield GLib.Bus.get_proxy<Gnome.ShellExtensions> (
                        GLib.BusType.SESSION,
                        "org.gnome.Shell",
                        "/org/gnome/Shell",
                        GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                        cancellable);
            }
            catch (GLib.Error error) {
                // GLib.warning ("Failed to connect to org.gnome.Shell.ShellExtensions: %s", error.message);
                throw error;
            }

            this.proxy.extension_state_changed.connect (this.on_extension_state_changed);
            // this.proxy.extension_status_changed.connect (this.on_status_changed);

            yield this.update_info ();

            return true;
        }

        private void on_info_changed ()
        {
        }

        private void on_extension_state_changed (string uuid,
                                                 HashTable<string,Variant> data)
        {
            if (uuid != this.uuid) {
                return;
            }

            try {
                this.info = Gnome.ExtensionInfo.deserialize (uuid, data);
            }
            catch (GLib.Error error) {
                this.info = Gnome.ExtensionInfo.with_defaults (uuid);
            }

            this.on_info_changed ();
        }


        private async void update_info (GLib.Cancellable? cancellable = null)
        {
            GLib.return_if_fail (this.proxy != null);

            HashTable<string,Variant> data;

            GLib.debug ("Fetching extension info of \"%s\"...", this.uuid);

            try {
                data = yield this.proxy.get_extension_info (this.uuid, cancellable);

                this.info = Gnome.ExtensionInfo.deserialize (this.uuid, data);

                GLib.debug ("Extension path: %s", this.info.path);
                GLib.debug ("Extension state: %s", this.info.state.to_string ());
            }
            catch (GLib.Error error) {
                GLib.critical ("%s", error.message);
                return;
            }

            this.on_info_changed ();
        }








        /**
         * Fetch extension info/state
         */
        private async void update (GLib.Cancellable? cancellable) throws GLib.Error
        {
            /*
            var cancellable_handler_id = (ulong) 0;

            if (!this.enabled && (cancellable == null || !cancellable.is_cancelled ()))
            {
                var handler_id = this.notify["enabled"].connect_after (() => {
                    if (this.enabled) {
                        this.ensure_enabled.callback ();
                    }
                });

                if (cancellable != null) {
                    cancellable_handler_id = cancellable.cancelled.connect (() => {
                        this.ensure_enabled.callback ();
                    });
                }

                yield;

                this.disconnect (handler_id);

                if (cancellable != null) {
                    // cancellable.disconnect() causes a deadlock here
                    GLib.SignalHandler.disconnect (cancellable, cancellable_handler_id);
                }
            }

            if (this.enabled && (cancellable == null || !cancellable.is_cancelled ()))
            {
                yield Pomodoro.DesktopExtension.get_default ().initialize (cancellable);
            }
            */
        }

        private async bool install (GLib.Cancellable? cancellable = null)
        {
            /*
            GLib.return_if_fail (this.proxy != null);

            if (cancellable != null && cancellable.is_cancelled ()) {
                return false;
            }

            GLib.debug ("Loading extension…");
            try {
                // TODO: should be async
                this.eval_script (LOAD_SCRIPT.replace ("${UUID}", this.uuid));

                yield this.update (cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to load extension: %s", error.message);
            }

            return this.state != Gnome.ExtensionState.UNINSTALLED;
        }

        /**
         * Try reloading the extension.
         *
         * Old version of the extension might be loaded.
         */
        public async bool reload (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
            if (cancellable != null && cancellable.is_cancelled ()) {
                return false;
            }

            if (this.state == Gnome.ExtensionState.UNINSTALLED || this.path == "") {
                return yield this.load (cancellable);
            }

            var previous_path = this.path;
            var previous_version = this.version;

            GLib.debug ("Reloading extension…");
            try {
                // TODO: should be async
                this.eval_script (RELOAD_SCRIPT.replace ("${UUID}", this.uuid));

                yield this.update (cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to reload extension: %s, %s '%s' '%s'", error.message, this.state.to_string (), previous_path, previous_version);
                throw new GnomeShellExtensionError.EVAL_ERROR (error.message);
            }

            return this.path != previous_path || this.version != previous_version;
        }

        /**
         * Try enabling the extension
         *
         * Will try loading the extension
         */
        public async bool enable (GLib.Cancellable? cancellable = null)
        {
            if (this.path == "") {
                try {
                    yield this.load ();
                }
                catch (GLib.Error error) {
                    GLib.warning ("Error while loading extension: %s", error.message);
                }
            }

            if (!this.shell_extensions_proxy.user_extensions_enabled) {
                GLib.warning ("Extensions in GNOME Shell are currently disabled. Use Extensions app to enable extensions.");
            }

            GLib.debug ("Enabling extension…");

            try {
                yield this.shell_extensions_proxy.enable_extension (this.uuid);

                yield this.update (cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while enabling extension: %s", error.message);
            }

            return this.state == Gnome.ExtensionState.ENABLED;
        }

        public async bool disable (GLib.Cancellable? cancellable = null)
        {
            try {
                yield this.shell_extensions_proxy.disable_extension (this.uuid);

                yield this.update (cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while disabling extension: %s", error.message);
            }

            return this.state != Gnome.ExtensionState.ENABLED;
        }

        public signal void state_changed ();

        public override void dispose ()
        {
            if (this.extension_state_changed_id != 0) {
                this.shell_extensions_proxy.disconnect (this.extension_state_changed_id);
            }

            GLib.Application.get_default ()
                            .withdraw_notification ("extension");

            base.dispose ();
        }
    }
}




        // private void on_status_changed (string uuid,
        //                                 int32  state,
        //                                 string error)
        // {
        //     if (uuid != this.uuid) {
        //         return;
        //     }
        //
        //     this.update_info ();
        //
        //     if (this.info != null)
        //     {
        //         GLib.debug ("Extension %s changed state to %s", uuid, this.info.state.to_string ());
        //
        //         this.state = this.info.state;
        //
        //         if (this.enabled) {
        //             this.notify_enabled ();
        //         }
        //     }
        // }

        // private async void eval (string            script,
        //                          GLib.Cancellable? cancellable = null)
        // {
        //     GLib.return_if_fail (this.proxy != null);

        //     if (cancellable != null && cancellable.is_cancelled ()) {
        //         return;
        //     }

        //     var handler_id = this.proxy.extension_status_changed.connect_after ((uuid, state, error) => {
        //         if (uuid == this.uuid) {
        //             this.eval.callback ();
        //         }
        //     });
        //     var cancellable_id = (ulong) 0;

        //     if (cancellable != null) {
        //         cancellable_id = cancellable.connect (() => {
        //             this.eval.callback ();
        //         });
        //     }

        //     try {
        //         var shell_proxy = GLib.Bus.get_proxy_sync<Gnome.Shell> (GLib.BusType.SESSION,
        //                                                                 "org.gnome.Shell",
        //                                                                 "/org/gnome/Shell",
        //                                                                 GLib.DBusProxyFlags.DO_NOT_AUTO_START);
        //         shell_proxy.eval (script);

        //         yield;
        //     }
        //     catch (GLib.Error error) {
        //         GLib.warning ("Failed to eval script: %s",
        //                       error.message);
        //     }

        //     if (cancellable_id != 0) {
        //         cancellable.disconnect (cancellable_id);
        //     }

        //     this.proxy.disconnect (handler_id);
        // }

//         /**
//          * GNOME Shell has no public API to enable extensions
//          */
//         private async void enable_internal (GLib.Cancellable? cancellable = null)
//         {
//             yield this.eval ("""
// (function() {
//     let uuid = '""" + this.uuid + """';
//     let enabledExtensions = global.settings.get_strv('enabled-extensions');

//     if (enabledExtensions.indexOf(uuid) == -1) {
//         enabledExtensions.push(uuid);
//         global.settings.set_strv('enabled-extensions', enabledExtensions);
//     }
// })();
// """, cancellable);
//         }

//         /**
//          * GNOME Shell may not be aware of freshly installed extension. Load it explicitly.
//          */
//         private async void load (GLib.Cancellable? cancellable = null)
//         {
//             yield this.eval ("""
// (function() {
//     let paths = [
//         global.userdatadir,
//         global.datadir
//     ];
//     let uuid = '""" + this.uuid + """';
//     let existing = ExtensionUtils.extensions[uuid];
//     if (existing) {
//         ExtensionSystem.unloadExtension(existing);
//     }
//
//     let perUserDir = Gio.File.new_for_path(global.userdatadir);
//     let type = dir.has_prefix(perUserDir) ? ExtensionUtils.ExtensionType.PER_USER
//                                           : ExtensionUtils.ExtensionType.SYSTEM;
//
//     try {
//         let extension = ExtensionUtils.createExtensionObject(uuid, dir, type);
//
//         ExtensionSystem.loadExtension(extension);
//
//         let enabledExtensions = global.settings.get_strv('enabled-extensions');
//         if (enabledExtensions.indexOf(uuid) == -1) {
//             enabledExtensions.push(uuid);
//             global.settings.set_strv('enabled-extensions', enabledExtensions);
//         }
//     } catch(e) {
//         logError(e, 'Could not load extension %s'.format(uuid));
//         return;
//     }
// })();
// """, cancellable);
//         }
