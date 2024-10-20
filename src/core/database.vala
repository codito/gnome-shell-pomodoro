using GLib;


namespace Pomodoro.Database
{
    private const uint VERSION = 2;
    private const string MIGRATIONS_URI = "resource:///org/gnomepomodoro/Pomodoro/migrations";

    private Gom.Adapter? adapter = null;
    private Gom.Repository? repository = null;

    public unowned Gom.Repository? get_repository ()
    {
        return Pomodoro.Database.repository;
    }

    private void make_directory_with_parents (GLib.File directory)
    {
        if (!directory.query_exists ())
        {
            try {
                directory.make_directory_with_parents ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to create directory: %s", error.message);
            }
        }
    }

    /**
     * Convenience function to execute multiline SQL.
     *
     * `Gom.Adapter.execute_sql` is limited to single line queries.
     *
     * This MUST be called from within a write transaction using
     * Gom.Adapter.queue_write().
     */
    private void execute_sql (Gom.Adapter adapter,
                              string      sql)
                              throws GLib.Error
    {
        unowned var database = adapter.get_handle ();
        string error_message;

        if (database.exec (sql, null, out error_message) != Sqlite.OK) {
            throw new Gom.Error.COMMAND_SQLITE (error_message);
        }
    }

    private bool migrate_repository (Gom.Repository repository,
                                     Gom.Adapter    adapter,
                                     uint           version)
                                     throws GLib.Error
    {
        uint8[] file_contents;

        GLib.info ("Migrating database to version %u", version);

        var file = File.new_for_uri (@"$(MIGRATIONS_URI)/version-$(version).sql");
        file.load_contents (null, out file_contents, null);

        // TODO: back-up before migrating

        try {
            Pomodoro.Database.execute_sql (adapter, (string) file_contents);
        }
        catch (GLib.Error error) {
            throw error;
        }

        return true;
    }

    private Gom.Repository? open_repository (Gom.Adapter adapter,
                                             GLib.File?  file)
    {
        Gom.Repository? repository = null;

        try {
            if (file != null) {
                make_directory_with_parents (file.get_parent ());
                adapter.open_sync (file.get_uri ());
            }
            else {
                adapter.open_sync (":memory:");
            }
        }
        catch (GLib.Error error) {
            GLib.error ("Failed to open database '%s': %s", file?.get_uri (), error.message);
            return null;
        }

        adapter.queue_write (
            () => {
                try {
                    adapter.execute_sql ("PRAGMA foreign_keys = ON;");
                }
                catch (GLib.Error error) {
                    GLib.warning ("Failed to enable 'foreign_keys': %s", error.message);
                }
            });

        try {
            repository = new Gom.Repository (adapter);
            repository.migrate_sync (Pomodoro.Database.VERSION,
                                     Pomodoro.Database.migrate_repository);
        }
        catch (GLib.Error error) {
            GLib.error ("Failed to migrate database: %s", error.message);
        }

        return repository;
    }

    private void close_repository (Gom.Repository repository)
    {
        var adapter = repository.adapter;

        try {
            adapter.close_sync ();
        }
        catch (GLib.Error error) {
            GLib.warning ("Error while closing database: %s", error.message);
        }
    }

    public void open ()
    {
        GLib.File? file = null;

        if (Pomodoro.Database.repository != null) {
            return;
        }

        if (!Pomodoro.is_test ())
        {
            if (Pomodoro.is_flatpak ()) {
                // TODO: copy file from ~/.local/share/gnome-pomodoro/database.sqlite
            }

            var file_path = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (),
                                                      Config.PACKAGE_NAME,
                                                      "database.sqlite");
            file = GLib.File.new_for_path (file_path);
        }

        Pomodoro.Database.adapter = new Gom.Adapter ();
        Pomodoro.Database.repository = open_repository (Pomodoro.Database.adapter, file);
    }

    public void close ()
    {
        if (Pomodoro.Database.repository == null) {
            return;
        }

        close_repository (Pomodoro.Database.repository);

        Pomodoro.Database.repository = null;
        Pomodoro.Database.adapter = null;
    }
}
