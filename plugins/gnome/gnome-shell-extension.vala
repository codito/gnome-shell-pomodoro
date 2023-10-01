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

if (extension)
    Main.extensionManager.reloadExtension(extension);
else
    throw new Error('Could not find extension %s'.format(uuid));
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

        /**
         * Fetch extension info/state
         */
        private async void update (GLib.Cancellable? cancellable) throws GLib.Error
        {
            HashTable<string,Variant> data;

            try {
                GLib.debug ("Fetching extension info of \"%s\"…", this.uuid);
                data = yield this.shell_extensions_proxy.get_extension_info (this.uuid, cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while fetching extension state: %s", error.message);
                throw error;
            }

            try {
                this.do_update (data);
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while updating extension state: %s", error.message);
                throw error;
            }
        }

        private void on_extension_state_changed (string                    uuid,
                                                 HashTable<string,Variant> data)
        {
            if (uuid != this.uuid) {
                return;
            }

            try {
                this.do_update (data);
            }
            catch (GLib.Error error) {
                GLib.warning ("%s", error.message);
            }
        }

        private void eval_script (string script) throws GLib.Error
        {
            var success = false;
            var result = "";

            this.shell_proxy.eval (
                SCRIPT_WRAPPER.replace ("${SCRIPT}", script),
                out success,
                out result);

            GLib.debug ("Eval result: %s %s", success ? "true" : "false", result);

            if (success && result == "null") {
                // no syntax error and no error message
            }
            else {
                throw new GnomeShellExtensionError.EVAL_ERROR (result);
            }
        }

        /**
         * GNOME Shell is not aware of freshly installed extensions.
         * Extension normally would be visible after logging out.
         * This function tries to load the extension the same way GNOME Shell does it.
         */
        public async bool load (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
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
                GLib.warning ("Failed to reload extension: %s", error.message);
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

            try {
                yield this.shell_extensions_proxy.enable_extension (this.uuid);
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
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while disabling extension: %s", error.message);
            }

            return this.state != Gnome.ExtensionState.ENABLED;
        }

        // FIXME: does not work
        public void show_preferences ()
        {
            GLib.debug ("Opening extension preferences…");

            this.shell_extensions_proxy.launch_extension_prefs.begin (this.uuid, (obj, result) => {
                try {
                    this.shell_extensions_proxy.launch_extension_prefs.end (result);
                }
                catch (GLib.Error error) {
                    GLib.warning ("Error opening extension preferences: %s", error.message);
                }
            });
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
