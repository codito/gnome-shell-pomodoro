CREATE TABLE "entries" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "datetime-string"       TEXT NOT NULL,  -- in UTC
    "datetime-local-string" TEXT NOT NULL,  -- local
    "state-name"            TEXT NOT NULL,
    "state-duration"        INTEGER DEFAULT 0,
    "elapsed"               INTEGER DEFAULT 0
);

CREATE TABLE "aggregated-entries" (
    "id"                    INTEGER PRIMARY KEY AUTOINCREMENT,
    "date-string"           TEXT NOT NULL,  -- local
    "state-name"            TEXT NOT NULL,
    "state-duration"        INTEGER DEFAULT 0,
    "elapsed"               INTEGER DEFAULT 0
);

CREATE INDEX "entries-datetime-local-string" ON "entries" (
    "datetime-local-string"
);
CREATE INDEX "aggregated-entries-date-string" ON "aggregated-entries" (
    "date-string"
);
CREATE UNIQUE INDEX "aggregated-entries-date-string-state-name" ON "aggregated-entries" (
    "date-string",
    "state-name"
);

CREATE TRIGGER "entries-insert" AFTER INSERT ON "entries" FOR EACH ROW
    BEGIN
        UPDATE "aggregated-entries"
            SET
                "elapsed" = "elapsed" + NEW."elapsed",
                "state-duration" = "state-duration" + NEW."state-duration"
            WHERE
                "date-string" = date(NEW."datetime-local-string") AND
                "state-name" = NEW."state-name";

        INSERT INTO "aggregated-entries" (
                "date-string",
                "state-name",
                "state-duration",
                "elapsed"
            )
            SELECT
                date(NEW."datetime-local-string"),
                NEW."state-name",
                NEW."state-duration",
                NEW."elapsed"
            WHERE
                changes() = 0;
    END;

CREATE TRIGGER "entries-update" AFTER UPDATE ON "entries" FOR EACH ROW
    BEGIN
        UPDATE "aggregated-entries"
            SET
                "elapsed" = "elapsed" + NEW."elapsed",
                "state-duration" = "state-duration" + NEW."state-duration"
            WHERE
                "date-string" = date(NEW."datetime-local-string") AND
                "state-name" = NEW."state-name";

        INSERT INTO "aggregated-entries" (
                "date-string",
                "state-name",
                "state-duration",
                "elapsed"
            )
            SELECT
                date(NEW."datetime-local-string"),
                NEW."state-name",
                NEW."state-duration",
                NEW."elapsed"
            WHERE
                changes() = 0;

        UPDATE "aggregated-entries"
            SET
                "elapsed" = "elapsed" - OLD."elapsed",
                "state-duration" = "state-duration" - OLD."state-duration"
            WHERE
                "date-string" = date(OLD."datetime-local-string") AND
                "state-name" = OLD."state-name";
    END;

CREATE TRIGGER "entries-delete" AFTER DELETE ON "entries" FOR EACH ROW
    BEGIN
        UPDATE "aggregated-entries"
            SET
                "elapsed" = "elapsed" - OLD."elapsed",
                "state-duration" = "state-duration" - OLD."state-duration"
            WHERE
                "date-string" = date(OLD."datetime-local-string") AND
                "state-name" = OLD."state-name";
    END;
