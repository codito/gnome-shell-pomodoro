namespace Pomodoro
{
    public interface Job : GLib.Object
    {
        public abstract bool        completed { get; set; default = false; }
        public abstract GLib.Error? error { get; set; default = null; }

        public abstract async bool run () throws GLib.Error;
    }


    /**
     * Run scheduled jobs sequentially. Currently we only run one type of jobs - actions / commands.
     * If there were more types, likely we would need to manage several queues / workers.
     */
    [SingleInstance]
    public class JobQueue : GLib.Object
    {
        private GLib.AsyncQueue<Pomodoro.Job> queue;
        private bool running = false;

        construct
        {
            this.queue = new GLib.AsyncQueue<Pomodoro.Job> ();
        }

        private void pop (bool may_block)
        {
            var job = may_block ? this.queue.pop () : this.queue.try_pop ();

            if (job == null) {
                return;
            }

            this.running = true;

            job.run.begin (
                (obj, res) => {
                    try {
                        job.run.end (res);
                    }
                    catch (GLib.Error error) {
                        assert (job.error != null);
                    }

                    assert (job.completed);

                    this.running = false;

                    this.pop (false);
                });
        }

        public void push (Pomodoro.Job job)
        {
            this.queue.push (job);

            if (!this.running) {
                this.pop (false);
            }
        }

        /**
         * Wait for the worker thread to finish.
         */
        public void wait ()
        {
            // TODO: either do work in a thread, or make wait async
        }
    }
}
