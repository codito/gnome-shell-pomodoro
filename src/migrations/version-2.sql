CREATE TABLE "sessions" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "start-time"            INTEGER NOT NULL UNIQUE,  -- Unix timestamp in microseconds, UTC
    "end-time"              INTEGER NOT NULL,         -- Unix timestamp in microseconds, UTC
    CHECK ("end-time" >= "start-time" OR "end-time" < 0)
);
CREATE INDEX "sessions-start-time" ON "sessions" ("start-time");

CREATE TABLE "time_blocks" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "session-id"            INTEGER NOT NULL,
    "start-time"            INTEGER NOT NULL UNIQUE,  -- Unix timestamp in microseconds, UTC
    "end-time"              INTEGER NOT NULL,         -- Unix timestamp in microseconds, UTC
    "state"                 TEXT NOT NULL,
    "status"                TEXT NOT NULL,
    "intended-duration"     INTEGER NOT NULL,         -- in microseconds
    FOREIGN KEY ("session-id") REFERENCES "sessions" ("id") ON DELETE CASCADE,
    CHECK ("end-time" >= "start-time" OR "end-time" < 0)
);
CREATE INDEX "time-blocks-session-id" ON "time_blocks" ("session-id");

CREATE TABLE "gaps" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "start-time"            INTEGER NOT NULL UNIQUE,  -- Unix timestamp in microseconds, UTC
    "end-time"              INTEGER NOT NULL,         -- Unix timestamp in microseconds, UTC
    "time-block-id"         INTEGER NOT NULL,         -- parent
    FOREIGN KEY ("time-block-id") REFERENCES "time_blocks" ("id") ON DELETE CASCADE,
    CHECK ("end-time" >= "start-time" OR "end-time" < 0)
);
CREATE INDEX "gaps-time-block-id" ON "gaps" ("time-block-id");

CREATE TABLE "timezones" (
    -- Extra `id` column is needed for Gom. We could just use `time` as the
    -- primary key, but Gom would override given values.
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "time"                  INTEGER NOT NULL UNIQUE,  -- Unix timestamp in microseconds, UTC
    "identifier"            TEXT NOT NULL
);

CREATE TABLE "stats" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "date"                  DATE NOT NULL,        -- date adjusted for virtual midnight
    "offset"                INTEGER NOT NULL,     -- offset in seconds, local time of day
    "duration"              INTEGER DEFAULT 0,    -- in seconds
    "category"              TEXT NOT NULL,
    "time-block-id"         INTEGER NULL,
    FOREIGN KEY ("time-block-id") REFERENCES "time_blocks" ("id") ON DELETE SET NULL
);
CREATE INDEX "stats-date" ON "stats" ("date");
CREATE INDEX "stats-time-block-id" ON "stats" ("time-block-id");

CREATE TABLE "aggregated-stats" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "date"                  DATE NOT NULL,        -- date adjusted for virtual midnight
    "category"              TEXT NOT NULL,
    "duration"              INTEGER DEFAULT 0     -- in seconds
);
CREATE INDEX "aggregated-stats-date" ON "aggregated-stats" ("date");
CREATE UNIQUE INDEX "aggregated-stats-date-category" ON "aggregated-stats" (
    "date",
    "category"
);

CREATE TRIGGER "stats-insert" AFTER INSERT ON "stats" FOR EACH ROW
    BEGIN
        UPDATE "aggregated-stats"
            SET
                "duration" = "duration" + NEW."duration"
            WHERE
                "date" = NEW."date" AND
                "category" = NEW."category";

        INSERT INTO "aggregated-stats" (
                "date",
                "category",
                "duration"
            )
            SELECT
                NEW."date",
                NEW."category",
                NEW."duration"
            WHERE
                changes() = 0;
    END;

CREATE TRIGGER "stats-update" AFTER UPDATE ON "stats" FOR EACH ROW
    BEGIN
        UPDATE "aggregated-stats"
            SET
                "duration" = "duration" + NEW."duration"
            WHERE
                "date" = NEW."date" AND
                "category" = NEW."category";

        INSERT INTO "aggregated-stats" (
                "date",
                "category",
                "duration"
            )
            SELECT
                NEW."date",
                NEW."category",
                NEW."duration"
            WHERE
                changes() = 0;

        UPDATE "aggregated-stats"
            SET
                "duration" = "duration" - OLD."duration"
            WHERE
                "date" = OLD."date" AND
                "category" = OLD."category";
    END;

CREATE TRIGGER "stats-delete" AFTER DELETE ON "stats" FOR EACH ROW
    BEGIN
        UPDATE "aggregated-stats"
            SET
                "duration" = "duration" - OLD."duration"
            WHERE
                "date" = OLD."date" AND
                "category" = OLD."category";
    END;

-- TODO: migrate "entries" into "stats"
-- TODO: delete "entries" and "aggregated-entries"
