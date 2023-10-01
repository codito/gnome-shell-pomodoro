namespace Pomodoro
{
    /**
     * A convenience class describing a cycle.
     *
     * Cycle consists of a single pomodoro and breaks following it. In case pomodoro comes right after another pomodoro
     * we treat it as new cycle to make session indicator more readable, although it's not true to a definition of
     * a cycle. Uncompleted time-blocks are included, therefore some cycles may be considered as invalid.
     *
     * Cycle does not serve as a container for time-blocks, its more like an annotation.
     */
    public class Cycle : GLib.Object
    {
        public unowned Pomodoro.Session session {
            get {
                unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

                return link != null ? link.data.session : null;
            }
        }

        public int64 start_time {
            get {
                return this._start_time;
            }
        }

        public int64 end_time {
            get {
                return this._end_time;
            }
        }

        public int64 duration {
            get {
                return Pomodoro.Timestamp.subtract (this._end_time, this._start_time);
            }
        }

        private GLib.List<Pomodoro.TimeBlock> time_blocks;
        private int64                         _start_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                         _end_time = Pomodoro.Timestamp.UNDEFINED;
        private int                           changed_freeze_count = 0;
        private bool                          changed_is_pending = false;
        private int64                         progress_reference_start_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                         progress_reference_end_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                         progress_paused_time = Pomodoro.Timestamp.UNDEFINED;
        private bool                          progress_empty = true;

        // Metadata
        private double                        weight = double.NAN;
        private int64                         completion_time = Pomodoro.Timestamp.UNDEFINED;

        construct
        {
            this.time_blocks = new GLib.List<Pomodoro.TimeBlock> ();
        }

        private void on_time_block_changed ()
        {
            this.emit_changed ();
        }

        private void emit_added (Pomodoro.TimeBlock time_block)
        {
            time_block.changed.connect (this.on_time_block_changed);

            this.added (time_block);
        }

        private void emit_removed (Pomodoro.TimeBlock time_block)
        {
            time_block.changed.disconnect (this.on_time_block_changed);

            this.removed (time_block);
        }

        private void emit_changed ()
        {
            if (this.changed_freeze_count > 0) {
                this.changed_is_pending = true;
            }
            else {
                this.changed_is_pending = false;
                this.changed ();
            }
        }

        public void freeze_changed ()
        {
            this.changed_freeze_count++;
        }

        public void thaw_changed ()
        {
            this.changed_freeze_count--;

            if (this.changed_freeze_count == 0 && this.changed_is_pending) {
                this.emit_changed ();
            }
        }

        private void update_time_range ()
        {
            unowned Pomodoro.TimeBlock first_time_block = this.get_first_time_block ();
            unowned Pomodoro.TimeBlock last_time_block = this.get_last_time_block ();

            var old_duration = this._end_time - this._start_time;

            var start_time = first_time_block != null
                ? first_time_block.start_time
                : Pomodoro.Timestamp.UNDEFINED;

            var end_time = last_time_block != null
                ? last_time_block.end_time
                : Pomodoro.Timestamp.UNDEFINED;

            if (this._start_time != start_time) {
                this._start_time = start_time;
                this.notify_property ("start-time");
            }

            if (this._end_time != end_time) {
                this._end_time = end_time;
                this.notify_property ("end-time");
            }

            if (this._end_time - this._start_time != old_duration) {
                this.notify_property ("duration");
            }
        }

        private void remove_link (GLib.List<Pomodoro.TimeBlock>? link)
        {
            if (link == null) {
                return;
            }

            var time_block = link.data;
            link.data = null;
            this.time_blocks.delete_link (link);

            this.emit_removed (time_block);
        }

        public void remove (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            if (link != null) {
                this.remove_link (link);
            }
            else {
                GLib.warning ("Ignoring `Cycle.remove()`. Time-block does not belong to the cycle.");
            }
        }

        public void append (Pomodoro.TimeBlock time_block)
        {
            this.time_blocks.append (time_block);

            this.emit_added (time_block);
        }

        public unowned Pomodoro.TimeBlock? get_first_time_block ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            return link != null ? link.data : null;
        }

        public unowned Pomodoro.TimeBlock? get_last_time_block ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.last ();

            return link != null ? link.data : null;
        }

        public bool contains (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            while (link != null)
            {
                if (link.data == time_block) {
                    return true;
                }

                link = link.next;
            }

            return false;
        }

        public void @foreach (GLib.Func<unowned Pomodoro.TimeBlock> func)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            while (link != null)
            {
                func (link.data);

                link = link.next;
            }
        }

        /*
         * Functions for metadata
         */

        public double get_weight ()
        {
            if (this.weight.is_nan ())
            {
                unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
                var weight = 0.0;

                while (link != null)
                {
                    if (link.data.get_status () != Pomodoro.TimeBlockStatus.UNCOMPLETED)
                    {
                        var time_block_weight = link.data.get_weight ();
                        weight = !time_block_weight.is_nan ()
                            ? weight + double.max (time_block_weight, 0.0)
                            : double.NAN;
                    }

                    link = link.next;
                }

                this.weight = weight;
            }

            return this.weight;
        }

        public int64 get_completion_time ()
        {
            if (Pomodoro.Timestamp.is_undefined (this.completion_time))
            {
                unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
                var completion_time = Pomodoro.Timestamp.UNDEFINED;
                var time_block_completion_time = Pomodoro.Timestamp.UNDEFINED;

                while (link != null)
                {
                    if (link.data.get_status () != Pomodoro.TimeBlockStatus.UNCOMPLETED &&
                        link.data.get_weight () > 0.0)
                    {
                        time_block_completion_time = link.data.get_completion_time ();
                        completion_time = Pomodoro.Timestamp.is_defined (time_block_completion_time)
                            ? time_block_completion_time
                            : link.data.end_time;
                    }

                    link = link.next;
                }

                this.completion_time = completion_time;
            }

            return this.completion_time;
        }

        public bool is_extra ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            while (link != null)
            {
                if (link.data.get_is_extra () && link.data.get_weight () > 0.0) {
                    return true;
                }

                link = link.next;
            }

            return false;
        }

        /**
         * Hide cycles that were uncompleted or extra cycles that hasn't started yet.
         */
        public bool is_visible ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            while (link != null)
            {
                if (link.data.get_status () != Pomodoro.TimeBlockStatus.UNCOMPLETED &&
                    link.data.get_weight () > 0.0)
                {
                    return link.data.get_is_extra ()
                        ? link.data.get_status () != Pomodoro.TimeBlockStatus.SCHEDULED
                        : true;
                }

                link = link.next;
            }

            return false;
        }

        public void prepare_progress (int64 timestamp)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
            var progress = 0.0;
            var total_progress = 0.0;
            var paused_time = Pomodoro.Timestamp.UNDEFINED;

            while (link != null)
            {
                var time_block_weight = link.data.get_weight ();
                var last_gap = link.data.get_last_gap ();

                if (link.data.get_status () != Pomodoro.TimeBlockStatus.UNCOMPLETED &&
                    link.data.get_status () != Pomodoro.TimeBlockStatus.SCHEDULED &&
                    time_block_weight != 0.0)
                {
                    progress += time_block_weight * link.data.calculate_progress (timestamp);
                    total_progress += time_block_weight;
                }

                if (last_gap != null && Pomodoro.Timestamp.is_undefined (last_gap.end_time)) {
                    paused_time = last_gap.start_time;
                }

                link = link.next;
            }

            this.progress_reference_end_time = this.get_completion_time ();
            this.progress_paused_time = paused_time;

            if (Pomodoro.Timestamp.is_defined (paused_time)) {
                timestamp = paused_time;
            }

            if (progress < total_progress) {
                this.progress_reference_start_time = (int64) (
                    ((total_progress * (double) timestamp) - (progress * (double) this.progress_reference_end_time)) /
                    (total_progress - progress));
                this.progress_empty = false;
            }
            else {
                this.progress_reference_start_time = this.progress_reference_end_time;
                this.progress_empty = total_progress == 0.0;
            }
        }

        /**
         * Calculate cycle progress. It may go out of range 0.0-1.0.
         *
         * Time-blocks marked as UNCOMPLETED are ignored. Uses cache to make following calls cheaper to estimate.
         * Calculating progress
         */
        public double calculate_progress (int64 timestamp)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (Pomodoro.Timestamp.is_undefined (this._end_time) ||
                Pomodoro.Timestamp.is_undefined (this._start_time) ||
                timestamp < this._start_time)
            {
                return double.NAN;
            }

            if (Pomodoro.Timestamp.is_undefined (this.progress_reference_start_time)) {
                this.prepare_progress (timestamp);
            }

            if (this.progress_empty) {
                return double.NAN;
            }

            if (this.progress_reference_start_time >= this.progress_reference_end_time) {
                return 1.0;
            }

            if (Pomodoro.Timestamp.is_defined (this.progress_paused_time)) {
                timestamp = this.progress_paused_time;
            }

            return ((double) (timestamp - this.progress_reference_start_time) /
                    (double) (this.progress_reference_end_time - this.progress_reference_start_time)).clamp (0.0, 1.0);
        }

        public int64 calculate_progress_duration (int64 timestamp)
        {
            if (Pomodoro.Timestamp.is_undefined (this.progress_reference_start_time))
            {
                Pomodoro.ensure_timestamp (ref timestamp);
                this.prepare_progress (timestamp);
            }

            return Pomodoro.Timestamp.subtract (this.progress_reference_end_time, this.progress_reference_start_time);
        }

        /**
         * Invalidate cache. Cache helps avoiding re-iterating time-blocks for certain operations.
         *
         * You should call it on every time-block change or change of metadata.
         */
        public void invalidate_cache ()
        {
            this.weight = double.NAN;
            this.completion_time = Pomodoro.Timestamp.UNDEFINED;
            this.progress_reference_start_time = Pomodoro.Timestamp.UNDEFINED;
            this.progress_reference_end_time = Pomodoro.Timestamp.UNDEFINED;
            this.progress_paused_time = Pomodoro.Timestamp.UNDEFINED;
        }

        public bool is_scheduled ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            var first_status = link != null
                ? link.data.get_status ()
                : Pomodoro.TimeBlockStatus.SCHEDULED;

            return first_status == Pomodoro.TimeBlockStatus.SCHEDULED;
        }

        public bool is_completed ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
            var progress = 0.0;

            while (link != null)
            {
                if (link.data.get_status () == Pomodoro.TimeBlockStatus.COMPLETED) {
                    progress += link.data.get_weight ();
                }

                if (progress >= 1.0) {
                    return true;
                }

                link = link.next;
            }

            return false;
        }

        public override void dispose ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link;

            while ((link = this.time_blocks.first ()) != null)
            {
                link.data.changed.disconnect (this.on_time_block_changed);
                link.data = null;

                this.time_blocks.delete_link (link);
            }

            base.dispose ();
        }


        /*
         * Signals
         */


        [Signal (run = "last")]
        public signal void added (Pomodoro.TimeBlock time_block)
        {
            this.emit_changed ();
        }

        [Signal (run = "last")]
        public signal void removed (Pomodoro.TimeBlock time_block)
        {
            this.emit_changed ();
        }

        [Signal (run = "first")]
        public signal void changed ()
        {
            this.invalidate_cache ();
            this.update_time_range ();
        }
    }
}
