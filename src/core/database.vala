using GLib;


namespace Pomodoro
{
    private const uint REPOSITORY_VERSION = 1;

    private Gom.Adapter? adapter;
    private Gom.Repository? repository;


    public Gom.Repository? get_repository ()
    {
        return repository;

        // var application = Pomodoro.Application.get_default ();

        // return (Gom.Repository) application.get_repository ();
    }

    private bool migrate_repository (Gom.Repository repository,
                                     Gom.Adapter    adapter,
                                     uint           version)
                                     throws GLib.Error
    {
        uint8[] file_contents;
        string error_message;

        GLib.debug ("Migrating database to version %u", version);

        var file = File.new_for_uri (
            "resource:///org/gnomepomodoro/Pomodoro/migrations/version-%u.sql".printf (version)
        );
        file.load_contents (null, out file_contents, null);

        /* Gom.Adapter.execute_sql is limited to single line queries,
         * so we need to use Sqlite API directly
         */
        unowned Sqlite.Database database = adapter.get_handle ();

        if (database.exec ((string) file_contents, null, out error_message) != Sqlite.OK)
        {
            throw new Gom.Error.COMMAND_SQLITE (error_message);
        }

        return true;
    }

    public Gom.Repository? open_repository (GLib.File file)
    {
        var directory = file.get_parent ();

        if (!directory.query_exists ()) {
            try {
                directory.make_directory_with_parents ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to create directory: %s", error.message);
            }
        }

        try {
            /* Open database handle */
            var adapter = new Gom.Adapter ();
            adapter.open_sync (file.get_uri ());
            Pomodoro.adapter = adapter;

            /* Migrate database if needed */
            var repository = new Gom.Repository (adapter);
            repository.migrate_sync (Pomodoro.REPOSITORY_VERSION,
                                     Pomodoro.migrate_repository);
            Pomodoro.repository = repository;

            return repository;
        }
        catch (GLib.Error error) {
            GLib.critical ("Failed to migrate database: %s", error.message);
            return null;
        }
    }

    public void close_repository ()
    {
        try {
            if (Pomodoro.adapter != null) {
                Pomodoro.adapter.close_sync ();
            }
        }
        catch (GLib.Error error) {
        }

        Pomodoro.adapter = null;
        Pomodoro.repository = null;
    }
}
