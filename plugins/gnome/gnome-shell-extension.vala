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
    private const string FLATPAK_DATA_DIR = "/app/share";

    private void copy_recursive (GLib.File src,
                                 GLib.File dest,
                                 GLib.FileCopyFlags flags = GLib.FileCopyFlags.NONE,
                                 GLib.Cancellable? cancellable = null) throws GLib.Error
    {
        GLib.FileType src_type = src.query_file_type (GLib.FileQueryInfoFlags.NONE, cancellable);

        if (src_type == GLib.FileType.DIRECTORY) {
            dest.make_directory (cancellable);
            src.copy_attributes (dest, flags, cancellable);

            var src_path = src.get_path ();
            var dest_path = dest.get_path ();
            GLib.FileEnumerator enumerator = src.enumerate_children (GLib.FileAttribute.STANDARD_NAME,
                                                                     GLib.FileQueryInfoFlags.NONE,
                                                                     cancellable);

            for (GLib.FileInfo? info = enumerator.next_file (cancellable); info != null; info = enumerator.next_file (cancellable))
            {
                copy_recursive (
                    GLib.File.new_for_path (GLib.Path.build_filename (src_path, info.get_name ())),
                    GLib.File.new_for_path (GLib.Path.build_filename (dest_path, info.get_name ())),
                    flags,
                    cancellable);
            }
        }
        else if (src_type == GLib.FileType.REGULAR) {
            src.copy (dest, flags, cancellable);
        }
    }


    private class GnomeShellExtension : GLib.Object, GLib.AsyncInitable
    {
        SYNC_ERROR,
        EVAL_ERROR
    }


    internal class GnomeShellExtension : GLib.Object, GLib.AsyncInitable
    {
        public string uuid {
            get;
            construct set;
        }

        public string path {
            get;
            private set;
        }

        public string version {
            get;
            private set;
        }

        public Gnome.ExtensionState state {
            get;
            private set;
            default = Gnome.ExtensionState.UNINSTALLED;
        }

        // public Gnome.ExtensionInfo info {  // TODO make it private?
        //     get;
        //     private set;
        // }

        // public bool enabled {
        //     get {
        //         return this.info.state == Gnome.ExtensionState.ENABLED;
        //     }
        // }

        private Gnome.Shell           shell_proxy;
        private Gnome.ShellExtensions shell_extensions_proxy;
        private ulong                 extension_state_changed_id = 0;


        public GnomeShellExtension (string uuid) throws GLib.Error
        {
            GLib.Object (uuid: uuid,
                         path: "",
                         version: "",
                         state: ExtensionState.UNINSTALLED);
        }

        // construct
        // {
        //     this.info = Gnome.ExtensionInfo.with_defaults (this.uuid);
        // }

        /**
         * Initialize D-Bus proxy and fetch extension state
         */
        public virtual async bool init_async (int          io_priority = GLib.Priority.DEFAULT,
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
                GLib.warning ("Failed to connect to org.gnome.Shell: %s", error.message);
                throw error;
            }

            try {
                yield this.get_extension_info ();
            }
            catch (GLib.Error error) {
                throw error;
            }

            this.proxy.extension_state_changed.connect (this.on_extension_state_changed);

            return true;
        }

        private void get_extension_info () throws GLib.Error
        {
            try {
                GLib.debug ("Fetching extension info of \"%s\"...", this.uuid);
                var info_data = yield this.proxy.get_extension_info (this.uuid, cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while fetching extension state: %s", error.message);
                throw error;
            }

            this.on_extension_state_changed (this.uuid, info_data);
        }

        private void on_extension_state_changed (string                    uuid,
                                                 HashTable<string,Variant> data)
        {
            if (uuid != this.uuid) {
                return;
            }

            try {
                var info = Gnome.ExtensionInfo.deserialize (this.uuid, data);

                if (info.state != Gnome.ExtensionState.UNINSTALLED) {
                    this.path = info.path;
                    this.version = info.version;
                }

                this.state = info.state;
            }
            catch (GLib.Error error) {
                GLib.warning ("%s", error.message);
                return;
            }

            this.state_changed ();
        }

        private async bool eval (string script,
                                 GLib.Cancellable? cancellable = null)
        {
            GLib.return_if_fail (this.proxy != null);

            if (cancellable != null && cancellable.is_cancelled ()) {
                return;
            }

            try {
                var shell_proxy = yield GLib.Bus.get_proxy<Gnome.Shell> (GLib.BusType.SESSION,
                                                                        "org.gnome.Shell",
                                                                        "/org/gnome/Shell",
                                                                        GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                                                                        cancellable);
                return yield shell_proxy.eval (script);
            }
            catch (GLib.Error error) {
                 GLib.warning ("Failed to eval script: %s", error.message);
            }

            return false;
        }

        /**
         * GNOME Shell is not aware of freshly installed extensions.
         * Extension normally would be visible after logging out.
         * This function tries to load the extension the same way GNOME Shell does it.
         */
        private async void load (GLib.Cancellable? cancellable = null)
        {
            GLib.return_if_fail (this.proxy != null);

            if (cancellable != null && cancellable.is_cancelled ()) {
                return;
            }

            GLib.debug ("Loading extension…");

            var success = yield this.eval ("""
(function() {
    let perUserDir = Gio.File.new_for_path(global.userdatadir);
    let uuid = '""" + this.uuid + """';

    FileUtils.collectFromDatadirs('extensions', true, (dir, info) => {
        let fileType = info.get_file_type();
        if (fileType != Gio.FileType.DIRECTORY)
            return;

        if (info.get_name() != uuid)
            return;

        let existing = Main.extensionManager.lookup(uuid);
        if (existing) {
            return;
        }

        let type = dir.has_prefix(perUserDir)
            ? ExtensionType.PER_USER
            : ExtensionType.SYSTEM;
        try {
            extension = Main.extensionManager.createExtensionObject(uuid, dir, type);
        } catch (error) {
            logError(error, 'Could not load extension %s'.format(uuid));
            return;
        }
        Main.extensionManager.loadExtension(extension);
    });

    let extension = Main.extensionManager.lookup(uuid);
    if (!extension)
        throw new Error('Could not find extension %s'.format(uuid));
})();
""", cancellable);

    // let dir = Gio.File.new_for_path('""" + this.path + """');
    // let type = dir.has_prefix(perUserDir)
    //             ? ExtensionType.PER_USER
    //             : ExtensionType.SYSTEM;
    // let extension = Main.extensionManager.createExtensionObject(uuid, dir, type);

    // Main.extensionManager.loadExtension(extension);

    // if (!Main.extensionManager.enableExtension(uuid))
    //     throw new Error('Cannot enable %s'.format(uuid));

            if (success) {
                GLib.debug ("Loaded extension");
                yield this.get_extension_info ();
            }
            else {
                GLib.debug ("Failed to load extension");
            }
        }

        /**
         * D-Bus API for reloading extensions don't work.
         * Try reloading the extension.
         */
        private async void reload (GLib.Cancellable? cancellable = null)
        {
            GLib.return_if_fail (this.proxy != null);

            if (cancellable != null && cancellable.is_cancelled ()) {
                return;
            }

            GLib.debug ("Reloading extension…");
            var success = yield this.eval ("""
(function() {
    let uuid = '""" + this.uuid + """';
    let extension = Main.extensionManager.lookup(uuid);

    if (extension)
        Main.extensionManager.reloadExtension(extension);
    else
        throw new Error('Could not find extension %s'.format(uuid));
})();
""", cancellable);

            if (success) {
                GLib.debug ("Reloaded extension");
                yield this.get_extension_info ();
            }
            else {
                GLib.debug ("Failed to reload extension");
            }
        }


        /**
         * Try enabling the extension
         */
        private async void try_enable (bool              retry,
                                       GLib.Cancellable? cancellable = null)
        {
            switch (this.info.state)
            {
                case Gnome.ExtensionState.ENABLED:
                    break;

                case Gnome.ExtensionState.DISABLED:
                    yield this.proxy.enable_extension (this.uuid);
                    // TODO: wait until info.state changes
                    break;

                case Gnome.ExtensionState.UNINSTALLED:
                    if (retry) {
                        // TODO: only install if in flatpak
                        // yield this.install (cancellable);

                        yield this.load (cancellable);
                        yield this.try_enable (true, cancellable);
                    }

                    break;

                default:
                    break;
            }
        }

        public async bool enable (GLib.Cancellable? cancellable = null)
        {
            yield this.try_enable (true, cancellable);

            return this.enabled;
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

/*
function uninstallExtension(uuid) {
    let extension = Main.extensionManager.lookup(uuid);
    if (!extension)
        return false;

    // Don't try to uninstall system extensions
    if (extension.type !== ExtensionUtils.ExtensionType.PER_USER)
        return false;

    if (!Main.extensionManager.unloadExtension(extension))
        return false;

    FileUtils.recursivelyDeleteDir(extension.dir, true);

    try {
        const updatesDir = Gio.File.new_for_path(GLib.build_filenamev(
            [global.userdatadir, 'extension-updates', extension.uuid]));
        FileUtils.recursivelyDeleteDir(updatesDir, true);
    } catch (e) {
        // not an error
    }

    return true;
}
*/
