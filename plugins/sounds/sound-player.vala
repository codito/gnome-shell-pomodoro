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


namespace SoundsPlugin
{
    public errordomain SoundPlayerError
    {
        FAILED_TO_INITIALIZE
    }

    /**
     * Preset sounds are defined relative to data directory,
     * and used URIs are not particulary valid.
     */
    private string get_absolute_uri (string uri)
    {
        var scheme = GLib.Uri.parse_scheme (uri);

        if (scheme == null && uri != "")
        {
            var path = GLib.Path.build_filename (Config.PACKAGE_DATA_DIR,
                                                 "sounds",
                                                 uri);

            try {
                return GLib.Filename.to_uri (path);
            }
            catch (GLib.ConvertError error) {
                GLib.warning ("Failed to convert \"%s\" to uri: %s", path, error.message);
            }
        }

        return uri;
    }

    public interface SoundPlayer : GLib.Object
    {
        public abstract GLib.File? file { get; set; }

        public abstract double volume { get; set; }

        public abstract void play ();

        public abstract void stop ();

        public virtual string[] get_supported_mime_types ()
        {
            string[] mime_types = {
                "audio/*"
            };

            return mime_types;
        }
    }

    private interface Fadeable
    {
        public abstract void fade_in (uint duration);

        public abstract void fade_out (uint duration);
    }

    private class GStreamerPlayer : GLib.Object, SoundPlayer, Fadeable
    {
        public GLib.File? file {
            get {
                return this._file;
            }
            set {
                this._file = value;

                var uri = get_absolute_uri (this._file != null ? this._file.get_uri () : "");

                if (uri == "") {
                    this.stop ();
                }
                else {
                    Gst.State state;
                    Gst.State pending_state;

                    this.pipeline.get_state (out state,
                                             out pending_state,
                                             Gst.CLOCK_TIME_NONE);

                    if (pending_state != Gst.State.VOID_PENDING) {
                        state = pending_state;
                    }

                    if (state == Gst.State.PLAYING ||
                        state == Gst.State.PAUSED)
                    {
                        this.is_about_to_finish = false;

                        this.pipeline.set_state (Gst.State.READY);
                        this.pipeline.uri = uri;
                        this.pipeline.set_state (state);
                    }
                }
            }
        }

        public double volume {
            get {
                if (this.pipeline != null && this.pipeline.volume != null) {
                    return this.pipeline.volume;
                } else {
                    return 1.0;
                }
            }
            set {
                this.pipeline.volume = value.clamp (0.0, 1.0);
            }
        }

        public double volume_fade {
            get {
                if (this.volume_filter != null && this.volume_filter.volume != null) {
                    return this.volume_filter.volume;
                } else {
                    return 0.0;
                }
            }
            set {
                this.volume_filter.volume = value.clamp (0.0, 1.0);
            }
        }

        public bool repeat { get; set; default = false; }

        private GLib.File _file;
        private dynamic Gst.Element pipeline;
        private dynamic Gst.Element volume_filter;
        private Pomodoro.Animation volume_animation;
        private bool is_about_to_finish = false;
        private bool retry_on_error = true;

        [Flags]
        private enum GstPlayFlags {
            VIDEO             = 0x00000001,
            AUDIO             = 0x00000002,
            TEXT              = 0x00000004,
            VIS               = 0x00000008,
            SOFT_VOLUME       = 0x00000010,
            NATIVE_AUDIO      = 0x00000020,
            NATIVE_VIDEO      = 0x00000040,
            DOWNLOAD          = 0x00000080,
            BUFFERING         = 0x00000100,
            DEINTERLACE       = 0x00000200,
            SOFT_COLORBALANCE = 0x00000400,
            FORCE_FILTERS     = 0x00000800
        }

        private const uint FADE_FRAMES_PER_SECOND = 20;

        public GStreamerPlayer () throws SoundPlayerError
        {
            dynamic Gst.Element pipeline = Gst.ElementFactory.make ("playbin", "player");
            dynamic Gst.Element volume_filter = Gst.ElementFactory.make ("volume", "volume");

            if (pipeline == null) {
                throw new SoundPlayerError.FAILED_TO_INITIALIZE ("Failed to initialize \"playbin\" element");
            }

            if (volume_filter == null) {
                throw new SoundPlayerError.FAILED_TO_INITIALIZE ("Failed to initialize \"volume\" element");
            }

            pipeline.flags = GstPlayFlags.AUDIO;
            pipeline.audio_filter = volume_filter;
            pipeline.about_to_finish.connect (this.on_about_to_finish);
            pipeline.get_bus ().add_watch (GLib.Priority.DEFAULT,
                                           this.on_bus_callback);

            pipeline.volume = 1.0;
            volume_filter.volume = 0.0;

            this.volume_filter = volume_filter;
            this.pipeline = pipeline;
        }

        ~GStreamerPlayer ()
        {
            if (this.pipeline != null) {
                this.pipeline.set_state (Gst.State.NULL);
            }
        }

        public void play ()
                    requires (this.pipeline != null)
        {
            this.fade_in (0);
        }

        public void stop ()
                    requires (this.pipeline != null)
        {
            this.fade_out (0);
        }

        public void fade_in (uint duration)
        {
            if (this.volume_animation != null) {
                this.volume_animation.stop ();
                this.volume_animation = null;
            }

            if (duration > 0) {
                this.volume_animation = new Pomodoro.Animation (Pomodoro.AnimationMode.EASE_OUT,
                                                                duration,
                                                                FADE_FRAMES_PER_SECOND);
                this.volume_animation.add_property (this,
                                                    "volume-fade",
                                                    1.0);
                this.volume_animation.start ();
            }
            else {
                this.volume_fade = 1.0;
            }

            var uri = get_absolute_uri (this._file != null ? this._file.get_uri () : "");

            if (uri != "") {
                this.retry_on_error = true;

                this.pipeline.uri = uri;
                this.pipeline.set_state (Gst.State.PLAYING);
            }
        }

        public void fade_out (uint duration)
        {
            Gst.State state;
            Gst.State pending_state;

            if (this.volume_animation != null) {
                this.volume_animation.stop ();
                this.volume_animation = null;
            }

            this.pipeline.get_state (out state,
                                     out pending_state,
                                     Gst.CLOCK_TIME_NONE);

            if (pending_state != Gst.State.VOID_PENDING) {
                state = pending_state;
            }

            if (duration > 0 && state == Gst.State.PLAYING) {
                this.volume_animation = new Pomodoro.Animation (Pomodoro.AnimationMode.EASE_IN_OUT,
                                                                duration,
                                                                FADE_FRAMES_PER_SECOND);
                this.volume_animation.add_property (this,
                                                    "volume-fade",
                                                    0.0);
                this.volume_animation.complete.connect (() => {
                    this.stop ();
                });

                this.volume_animation.start ();
            }
            else {
                if (state != Gst.State.NULL && state != Gst.State.READY) {
                    this.pipeline.set_state (Gst.State.READY);
                }

                this.volume_fade = 0.0;
            }
        }

        private bool on_bus_callback (Gst.Bus     bus,
                                      Gst.Message message)
        {
            GLib.Error error;
            Gst.State state;
            Gst.State pending_state;

            this.pipeline.get_state (out state,
                                     out pending_state,
                                     Gst.CLOCK_TIME_NONE);

            switch (message.type)
            {
                case Gst.MessageType.EOS:
                    if (this.is_about_to_finish) {
                        this.is_about_to_finish = false;
                    }
                    else {
                        this.finished ();
                    }

                    if (pending_state != Gst.State.PLAYING) {
                        this.pipeline.set_state (Gst.State.READY);
                    }

                    break;

                case Gst.MessageType.ERROR:
                    if (this.is_about_to_finish) {
                        this.is_about_to_finish = false;
                    }

                    message.parse_error (out error, null);
                    GLib.critical (error.message);

                    this.pipeline.set_state (Gst.State.NULL);

                    if (this.retry_on_error) {
                        this.retry_on_error = false;
                        this.pipeline.set_state (Gst.State.PLAYING);
                    }
                    else {
                        this.finished ();
                    }

                    break;

                case Gst.MessageType.SEGMENT_DONE:
                    this.retry_on_error = true;
                    break;

                default:
                    break;
            }

            return GLib.Source.CONTINUE;
        }

        /**
         * Try emit "finished" signal before the end of stream.
         * If play gets called during then 
         */
        private void on_about_to_finish ()
        {
            this.is_about_to_finish = true;

            this.finished ();
        }

        public virtual signal void finished ()
        {
            string current_uri;

            if (this.repeat) {
                this.pipeline.get ("current-uri", out current_uri);

                if (current_uri != "") {
                    this.pipeline.set ("uri", current_uri);
                }
            }
        }
    }

    private class CanberraPlayer : GLib.Object, SoundPlayer
    {
        public GLib.File? file {
            get {
                return this._file;
            }
            set {
                this._file = value != null
                        ? GLib.File.new_for_uri (get_absolute_uri (value.get_uri ()))
                        : null;

                if (this.is_cached) {
                    /* there is no way to invalidate old value, so at least refresh cache */
                    this.cache_file ();
                }
            }
        }

        public string event_id { get; private construct set; }
        public double volume { get; set; default = 1.0; }

        private GLib.File _file;
        private GSound.Context context;
        private bool is_cached = false;

        public CanberraPlayer (string? event_id) throws SoundPlayerError
        {
            this.event_id = event_id;

            try {
                this.context = new GSound.Context ();
            }
            catch (GLib.Error error) {
                throw new SoundPlayerError.FAILED_TO_INITIALIZE ("Failed to initialize canberra context");
            }

            /* Set properties about application */
            var application = GLib.Application.get_default ();
            try {
                context.set_attributes (
                        GSound.Attribute.APPLICATION_ID, application.application_id,
                        GSound.Attribute.APPLICATION_NAME, Config.PACKAGE_NAME,
                        GSound.Attribute.APPLICATION_ICON_NAME, Config.PACKAGE_NAME);
            }
            catch (GLib.Error error) {
                throw new SoundPlayerError.FAILED_TO_INITIALIZE ("Failed to set context properties");
            }

            /* Try to connect to the sound system */
            try {
                context.open ();
            }
            catch (GLib.Error error) {
                /* it's ok to fail, will retry at play() */
            }
        }

        private static double amplitude_to_decibels (double amplitude)
        {
            return 20.0 * Math.log10 (amplitude);
        }

        public void play ()
                    requires (this.context != null)
        {
            if (this._file != null) {
                return;
            }

            if (this.context != null)
            {
                var volume = (float) amplitude_to_decibels (this.volume);

                if (this.event_id != null) {
                    if (!this.is_cached) {
                        this.cache_file ();
                    }
                }

                try {
                    this.context.play_simple (null,  /* cancellable */
                                              GSound.Attribute.MEDIA_ROLE, "alert",
                                              GSound.Attribute.MEDIA_FILENAME, this._file.get_path (),
                                              GSound.Attribute.CANBERRA_VOLUME, volume.to_string (),
                                              GSound.Attribute.EVENT_ID, this.event_id);
                }
                catch (GLib.Error error) {
                    GLib.warning ("Couldn't play sound '%s'",
                                  this._file.get_uri ());
                }
            }
            else {
                GLib.warning ("Couldn't play sound '%s'",
                              this._file.get_uri ());
            }
        }

        public void stop ()
                    requires (this.context != null)
        {
            /* we dont need it for event sounds */
        }

        public string[] get_supported_mime_types ()
        {
            string[] mime_types = {
                "audio/x-vorbis+ogg",
                "audio/x-wav"
            };

            return mime_types;
        }

        private void cache_file ()
        {
            if (this.context != null && this.event_id != null && this._file != null)
            {
                try {
                    this.context.cache (
                            GSound.Attribute.EVENT_ID, this.event_id,
                            GSound.Attribute.MEDIA_FILENAME, this._file.get_path ());
                    this.is_cached = true;
                }
                catch (GLib.Error error) {
                    GLib.warning ("Couldn't clear libcanberra cache");
                }
            }
        }
    }

    private class DummyPlayer : GLib.Object, SoundPlayer
    {
        public GLib.File? file {
            get {
                return this._file;
            }
            set {
                this._file = value != null
                        ? GLib.File.new_for_uri (get_absolute_uri (value.get_uri ()))
                        : null;
            }
        }

        public double volume { get; set; default = 1.0; }

        private GLib.File _file;

        public void play () {
        }

        public void stop () {
        }
    }
}
