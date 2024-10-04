/*
 * Copyright (c) 2016,2024 gnome-pomodoro contributors
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


namespace Pomodoro
{
    public enum Easing
    {
        IN,
        OUT,
        IN_OUT
    }

    private sealed class VolumeAnimation : GLib.Object
    {
        private const uint INTERVAL = 50;

        [CCode (notify = false)]
        public double value {
            get {
                return this._value;
            }
            set {
                if (this._value == value && this._value_to == value) {
                    return;
                }

                this.slope = 0.0;
                this._value = value;
                this._value_from = value;
                this._value_to = value;

                this.notify_property ("value-to");
                this.notify_property ("value");

                this.done ();
            }
        }

        public double value_to {
            get {
                return this._value_to;
            }
        }

        private double          _value = 1.0;
        private double          _value_from = 1.0;
        private double          _value_to = 1.0;
        private int64           monotonic_time_from = Pomodoro.Timestamp.UNDEFINED;
        private int64           monotonic_time_to = Pomodoro.Timestamp.UNDEFINED;
        private Pomodoro.Easing easing = Pomodoro.Easing.IN;
        private double          slope = 0.0;
        private uint            timeout_id = 0;

        public void animate_to (double          value,
                                int64           duration,
                                Pomodoro.Easing easing = Pomodoro.Easing.IN)
        {
            var monotonic_time = GLib.get_monotonic_time ();

            if (!GLib.double_equal (value, this._value) && duration > 0)
            {
                this.slope = this.calculate_slope (monotonic_time);
                this.monotonic_time_from = monotonic_time;
                this.monotonic_time_to = monotonic_time + duration;
                this._value_from = this._value;
                this._value_to = value;
                this.easing = easing;

                var interval = (uint) Math.round (
                    ((double) duration / 500000.0) / (this._value_to - this._value_from).abs ());

                if (this.timeout_id == 0) {
                    this.timeout_id = GLib.Timeout.add (uint.max (interval, 10), this.on_timeout);
                    GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.VolumeAnimation.on_timeout");
                }

                this.notify_property ("value-to");
            }
            else {
                this.slope = 0.0;
                this.monotonic_time_from = monotonic_time;
                this.monotonic_time_to = monotonic_time;
                this._value = value;
                this._value_from = value;
                this._value_to = value;
                this.easing = easing;

                this.notify_property ("value-to");
                this.notify_property ("value");

                this.done ();
            }
        }

        private double calculate_slope (int64 monotonic_time)
        {
            var t = (double) (monotonic_time - this.monotonic_time_from) /
                    (double) (this.monotonic_time_to - this.monotonic_time_from);
            t = t.clamp (0.0, 1.0);

            switch (this.easing)
            {
                case Pomodoro.Easing.OUT:
                    return 2.0 * (1.0 - t) * (this._value_to - this._value_from) +
                           (3.0 * t - 4.0) * this.slope * t + this.slope;

                case Pomodoro.Easing.IN:
                    return (2.0 * (this._value_to - this._value_from - this.slope * t) - this.slope) * t + this.slope;

                case Pomodoro.Easing.IN_OUT:
                    return 6.0 * (1.0 - t) * t * (this._value_to - this._value_from - this.slope * t);

                default:
                    assert_not_reached ();
            }
        }

        private double calculate_value (int64 monotonic_time)
        {
            var t = (double) (monotonic_time - this.monotonic_time_from) /
                    (double) (this.monotonic_time_to - this.monotonic_time_from);
            t = t.clamp (0.0, 1.0);

            switch (this.easing)
            {
                case Pomodoro.Easing.OUT:
                    return lerp (this._value_from + this.slope * t,
                                 this._value_to,
                                 (2.0 - t) * t);

                case Pomodoro.Easing.IN:
                    return lerp (this._value_from + this.slope * t,
                                 this._value_to,
                                 t * t);

                case Pomodoro.Easing.IN_OUT:
                    return lerp (this._value_from + this.slope * t,
                                 this._value_to,
                                 (3.0 - 2.0 * t) * (t * t));

                default:
                    assert_not_reached ();
            }
        }

        private bool on_timeout ()
        {
            var monotonic_time = GLib.MainContext.current_source ().get_time ();

            if (monotonic_time < this.monotonic_time_to)
            {
                this._value = this.calculate_value (monotonic_time);
                this.notify_property ("value");

                return GLib.Source.CONTINUE;
            }
            else {
                this._value = this._value_to;;
                this.notify_property ("value");

                this.timeout_id = 0;
                this.done ();

                return GLib.Source.REMOVE;
            }
        }

        public void stop ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }
        }

        public void skip ()
        {
            this.stop ();

            if (this._value != this._value_to)
            {
                this._value = this._value_to;
                this.notify_property ("value");

                this.done ();
            }
        }

        public signal void done ()
        {
            this.stop ();
        }

        public override void dispose ()
        {
            this.stop();

            base.dispose ();
        }
    }


    private string build_absolute_path (string path)
    {
        return GLib.Path.build_filename (Config.PACKAGE_DATA_DIR, "sounds", path);
    }

    private string build_absolute_uri (string uri)
    {
        var scheme = GLib.Uri.parse_scheme (uri);

        if (scheme == null && uri != "")
        {
            var preset_filename = uri;
            var preset_path = build_absolute_path (preset_filename);

            try {
                return GLib.Filename.to_uri (preset_path);
            }
            catch (GLib.ConvertError error) {
                GLib.warning ("Failed to convert \"%s\" to URI: %s", preset_path, error.message);
            }
        }

        return uri;
    }

    private bool transform_uri_to_uri (GLib.Binding   binding,
                                       GLib.Value     source_value,
                                       ref GLib.Value target_value)
    {
        var uri = source_value.get_string ();

        target_value.set_string (build_absolute_uri (uri));

        return true;
    }

    private bool transform_uri_to_path (GLib.Binding   binding,
                                        GLib.Value     source_value,
                                        ref GLib.Value target_value)
    {
        var uri = source_value.get_string ();

        if (uri == "" || uri == null) {
            target_value.set_string ("");
            return true;
        }

        var scheme = GLib.Uri.parse_scheme (uri);

        if (scheme == null)
        {
            var preset_filename = uri;
            var preset_path = build_absolute_path (preset_filename);

            target_value.set_string (preset_path);
        }
        else {
            try {
                target_value.set_string (GLib.Filename.from_uri (uri));
            }
            catch (GLib.ConvertError error) {
                GLib.warning ("Error converting '%s' to filename: %s", uri, error.message);
                return false;
            }
        }

        return true;
    }

    private double amplitude_to_decibels (double amplitude)
    {
        return 20.0 * Math.log10 (amplitude);
    }

    private bool is_mime_type (string   content_type,
                               string[] mime_types)
    {
        if (GLib.ContentType.is_unknown (content_type)) {
            return false;
        }

        foreach (var mime_type in mime_types)
        {
            if (GLib.ContentType.is_mime_type (content_type, mime_type)) {
                return true;
            }
        }

        return false;
    }


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


    public interface SoundBackend : GLib.Object
    {
        public abstract void play ();

        public abstract void stop ();

        public abstract bool is_playing ();

        public signal void playback_started ();
        public signal void playback_stopped ();
        public signal void playback_error (GLib.Error error);
    }


    private class GStreamerBackend : GLib.Object, Pomodoro.SoundBackend
    {
        public string uri {
            get {
                return this.pipeline.uri;
            }
            set {
                Gst.State state;
                Gst.State pending_state;

                this.pipeline.get_state (out state,
                                         out pending_state,
                                         Gst.CLOCK_TIME_NONE);

                if (pending_state != Gst.State.VOID_PENDING) {
                    state = pending_state;
                }

                if (state == Gst.State.PLAYING) {
                    this.pipeline.set_state (Gst.State.READY);
                    this.pipeline.uri = value;
                    this.pipeline.set_state (Gst.State.PLAYING);
                }
                else {
                    this.pipeline.uri = value;
                    this.pipeline.set_state (Gst.State.READY);
                }
            }
        }

        public double volume {
            get {
                return this.pipeline.volume;
            }
            set {
                this.pipeline.volume = value.clamp (0.0, 1.0);
            }
        }

        public double volume_fade {
            get {
                return this.volume_filter.volume;
            }
            set {
                this.volume_filter.volume = value.clamp (0.0, 1.0);
            }
        }

        public bool repeat { get; set; default = false; }

        private dynamic Gst.Element pipeline;
        private dynamic Gst.Element volume_filter;
        private bool                _is_playing = false;
        private bool                is_about_to_finish = false;

        private static bool is_gstreamer_initialized = false;

        public GStreamerBackend () throws GLib.Error
        {
            if (!is_gstreamer_initialized)
            {
                unowned string[] args_unowned = null;
                Gst.init (ref args_unowned);

                is_gstreamer_initialized = true;
            }

            dynamic Gst.Element pipeline = Gst.ElementFactory.make ("playbin", "player");
            dynamic Gst.Element volume_filter = Gst.ElementFactory.make ("volume", "volume");

            if (pipeline == null || volume_filter == null) {
                throw new Pomodoro.SoundError.NOT_INITIALIZED (_("Failed to initialize playback"));
            }

            pipeline.flags = GstPlayFlags.AUDIO;
            pipeline.audio_filter = volume_filter;
            pipeline.about_to_finish.connect (this.on_about_to_finish);
            pipeline.get_bus ().add_watch (GLib.Priority.DEFAULT, this.on_bus_callback);

            this.pipeline = pipeline;
            this.volume_filter = volume_filter;
        }

        public static string[] get_supported_mime_types ()
        {
            return {
                "audio/*"
            };
        }

        public static bool can_play (Pomodoro.Sound sound,
                                     GLib.File?     file,
                                     string         content_type)
        {
            return file != null && is_mime_type (content_type, GStreamerBackend.get_supported_mime_types ());
        }

        private void finished ()
        {
            string current_uri;

            if (this.repeat)
            {
                this.pipeline.get ("current-uri", out current_uri);

                if (current_uri != "") {
                    this.pipeline.set ("uri", current_uri);
                }
            }
        }

        private void on_about_to_finish ()
        {
            this.is_about_to_finish = true;

            this.finished ();
        }

        private bool on_bus_callback (Gst.Bus     bus,
                                      Gst.Message message)
        {
            Gst.State state;
            Gst.State pending_state;

            GLib.Error? error = null;

            this.pipeline.get_state (out state,
                                     out pending_state,
                                     Gst.CLOCK_TIME_NONE);

            switch (message.type)
            {
                case Gst.MessageType.STATE_CHANGED:
                    if (!this._is_playing && state == Gst.State.PLAYING) {
                        this._is_playing = true;
                        this.playback_started ();
                    }

                    if (this._is_playing && state != Gst.State.PLAYING) {
                        this._is_playing = false;
                        this.playback_stopped ();
                    }

                    break;

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

                    this.pipeline.set_state (Gst.State.NULL);
                    this.playback_error (error);
                    break;

                default:
                    break;
            }

            return GLib.Source.CONTINUE;
        }

        public void play ()
                          requires (this.pipeline != null)
        {
            if (this.uri != "") {
                this.pipeline.set_state (Gst.State.PLAYING);
            }
        }

        public void stop ()
        {
            Gst.State state;
            Gst.State pending_state;

            if (this.pipeline == null) {
                return;
            }

            this.pipeline.get_state (out state,
                                     out pending_state,
                                     Gst.CLOCK_TIME_NONE);

            if (pending_state != Gst.State.VOID_PENDING) {
                state = pending_state;
            }

            if (state != Gst.State.NULL && state != Gst.State.READY) {
                this.pipeline.set_state (Gst.State.READY);
            }
        }

        public bool is_playing ()
        {
            return this._is_playing;
        }

        public override void dispose ()
        {
            if (this.pipeline != null) {
                this.pipeline.set_state (Gst.State.NULL);
                this.pipeline = null;
            }

            base.dispose ();
        }
    }


    private class CanberraBackend : GLib.Object, Pomodoro.SoundBackend
    {
        public string event_id { get; set; }

        public string path {
            get {
                return this._path;
            }
            set {
                this._path = value;

                if (this.cancellable != null) {
                    this.cancellable.cancel ();
                    this.cancellable = null;
                }

                if (this._path != "" && this.event_id != "")
                {
                    try {
                        this.context.cache (GSound.Attribute.EVENT_ID, this.event_id,
                                            GSound.Attribute.MEDIA_FILENAME, this._path);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while caching '%s': %s", this._path, error.message);
                    };
                }
            }
        }

        public double volume { get; set; default = 1.0; }

        private string            _path = "";
        private GSound.Context?   context = null;
        private GLib.Cancellable? cancellable = null;

        public CanberraBackend () throws GLib.Error
        {
            try {
                context = new GSound.Context ();
                context.set_attributes (GSound.Attribute.APPLICATION_ID, Config.APPLICATION_ID,
                                        GSound.Attribute.APPLICATION_NAME, Config.PACKAGE_NAME,
                                        GSound.Attribute.APPLICATION_ICON_NAME, Config.APPLICATION_ID);
                context.open ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while initializing canberra: %s", error.message);

                throw new Pomodoro.SoundError.NOT_INITIALIZED (_("Failed to initialize playback"));
            }
        }

        public static string[] get_supported_mime_types ()
        {
            return {
                "audio/ogg",
                "audio/vnd.wave",
                "audio/x-vorbis+ogg",
                "audio/x-wav"
            };
        }

        public static bool can_play (Pomodoro.Sound sound,
                                     GLib.File?     file,
                                     string         content_type)
        {
            var alert_sound = sound as Pomodoro.AlertSound;

            if (alert_sound == null || alert_sound.event_id == "") {
                return false;
            }

            return file != null && file.is_native () && is_mime_type (content_type, get_supported_mime_types ());
        }

        public void play ()
                          requires (this.context != null)
                          requires (this.event_id != "")
        {
            if (this._path == "" || this.volume <= 0.0) {
                return;
            }

            if (this.cancellable != null) {
                this.cancellable.cancel ();
            }

            var cancellable = new GLib.Cancellable ();
            var decibels = amplitude_to_decibels (this.volume);

            try {
                this.context.play_simple (cancellable,
                                          GSound.Attribute.MEDIA_ROLE, "alert",
                                          GSound.Attribute.MEDIA_FILENAME, this._path,
                                          GSound.Attribute.CANBERRA_VOLUME, "%.3f".printf (decibels),
                                          GSound.Attribute.EVENT_ID, this.event_id);
                this.cancellable = cancellable;

                // Note: currently these signals are not emitted
                //       this.playback_started ();
                //       this.playback_stopped ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while playing %s: %s", this._path, error.message);

                this.playback_error (new Pomodoro.SoundError.NOT_INITIALIZED (_("Failed to initialize playback")));
            }
        }

        public void stop ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
            }
        }

        public bool is_playing ()
        {
            // Event sounds do not need to report that they are playing.

            return false;
        }

        public override void dispose ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
                this.cancellable = null;
            }

            this.context = null;

            base.dispose ();
        }
    }


    public errordomain SoundError
    {
        NOT_FOUND,
        NOT_INITIALIZED,
        NOT_SUPPORTED
    }


    /**
     * A sound player instance is intended for playing a single sound multiple times.
     */
    public abstract class Sound : GLib.Object
    {
        [CCode (notify = false)]
        public string uri {
            get {
                return this._uri;
            }
            set {
                if (this._uri == value && this.error != null)
                {
                    // Retry preparing if error happened.
                    this.prepare ();
                    return;
                }

                if (this._uri != value)
                {
                    this._uri = value;
                    this.prepare ();
                    this.notify_property ("uri");
                }
            }
        }

        public double volume { get; set; default = 1.0; }

        [CCode (notify = false)]
        public Pomodoro.SoundBackend? backend {
            get {
                return this._backend;
            }
        }

        public GLib.Error? error { get; private set; }

        private string                 _uri = "";
        private Pomodoro.SoundBackend? _backend = null;

        private void on_playback_error (GLib.Error error)
        {
            this.error = error;
        }

        private void prepare ()
        {
            var file = this._uri != "" ? GLib.File.new_for_uri (build_absolute_uri (this._uri)) : null;
            var content_type = file != null ? GLib.ContentType.guess (file.get_basename (), null, null) : "";
            var backend = this._backend;

            try {
                // Validate file.
                if (file != null && !file.query_exists ()) {
                    throw new Pomodoro.SoundError.NOT_FOUND (_("File not found"));
                }

                // Select backend.
                if (CanberraBackend.can_play (this, file, content_type))
                {
                    if (!(backend is CanberraBackend)) {
                        backend = new CanberraBackend ();
                    }
                }
                else if (GStreamerBackend.can_play (this, file, content_type))
                {
                    if (!(backend is GStreamerBackend)) {
                        backend = new GStreamerBackend ();
                    }
                }
                else {
                    if (file != null) {
                        throw new Pomodoro.SoundError.NOT_SUPPORTED (_("File type not supported"));
                    }

                    return;
                }

                // Initialize backend.
                if (this._backend != null) {
                    this.destroy_backend ();
                }

                this._backend = backend;
                this.error = null;

                if (backend != null) {
                    this.initialize_backend ();
                }
            }
            catch (GLib.Error error)
            {
                GLib.warning ("Error while initializing sound player: %s", error.message);

                if (this._backend != null) {
                    this.destroy_backend ();
                }

                this._backend = null;
                this.error = error;
            }

            this.notify_property ("backend");
            this.notify_property ("error");
        }

        public string[] get_supported_mime_types ()
        {
            return GStreamerBackend.get_supported_mime_types ();
        }

        public bool can_play ()
        {
            return this._backend != null;
        }

        public bool is_playing ()
        {
            return this._backend != null && this._backend.is_playing ();
        }

        public void play ()
        {
            if (this._backend != null) {
                this._backend.play ();
            }
        }

        public void stop ()
        {
            if (this._backend != null) {
                this._backend.stop ();
            }
        }

        protected virtual void initialize_backend ()
                                                   requires (this._backend != null)
        {
            this._backend.playback_error.connect (this.on_playback_error);
        }

        protected virtual void destroy_backend ()
                                                requires (this._backend != null)
        {
            this._backend.stop ();
            this._backend.playback_error.disconnect (this.on_playback_error);
        }

        public virtual void destroy ()
        {
            if (this._backend != null) {
                this.destroy_backend ();
                this._backend = null;
            }
        }
    }


    public class AlertSound : Pomodoro.Sound
    {
        public string event_id { get; construct; }

        public AlertSound (string event_id)
        {
            GLib.Object (
                event_id: event_id
            );
        }

        protected override void initialize_backend ()
        {
            base.initialize_backend ();

            if (this.backend is CanberraBackend)
            {
                this.bind_property ("event-id", backend, "event-id", GLib.BindingFlags.SYNC_CREATE);
                this.bind_property ("uri", backend, "path", GLib.BindingFlags.SYNC_CREATE, transform_uri_to_path, null);
                this.bind_property ("volume", backend, "volume", GLib.BindingFlags.SYNC_CREATE);
            }

            if (this.backend is GStreamerBackend)
            {
                this.bind_property ("uri", backend, "uri", GLib.BindingFlags.SYNC_CREATE, transform_uri_to_uri, null);
                this.bind_property ("volume", backend, "volume", GLib.BindingFlags.SYNC_CREATE);
            }
        }
    }


    public class BackgroundSound : Pomodoro.Sound
    {
        public bool repeat { get; set; default = false; }

        private Pomodoro.VolumeAnimation? volume_animation = null;
        private int64                     pending_fade_out_duration = 0;
        private int64                     pending_fade_out_easing = Pomodoro.Easing.IN_OUT;

        construct
        {
            this.volume_animation = new Pomodoro.VolumeAnimation ();
            this.volume_animation.done.connect (this.on_volume_animation_done);
        }

        private void on_volume_animation_done (Pomodoro.VolumeAnimation volume_animation)
        {
            var fade_out_duration = this.pending_fade_out_duration;
            var fade_out_easing = this.pending_fade_out_easing;

            if (fade_out_duration > 0) {
                this.fade_out (fade_out_duration, fade_out_easing);
                return;
            }

            if (GLib.double_equal (volume_animation.value, 0.0)) {
                this.stop ();
            }
        }

        protected override void initialize_backend ()
        {
            base.initialize_backend ();

            if (this.backend is GStreamerBackend)
            {
                this.bind_property ("uri", backend, "uri", GLib.BindingFlags.SYNC_CREATE, transform_uri_to_uri, null);
                this.bind_property ("volume", backend, "volume", GLib.BindingFlags.SYNC_CREATE);
                this.bind_property ("repeat", backend, "repeat", GLib.BindingFlags.SYNC_CREATE);
                this.volume_animation.bind_property ("value", backend, "volume-fade", GLib.BindingFlags.SYNC_CREATE);
            }
        }

        protected override void destroy_backend ()
        {
            this.backend.playback_stopped.disconnect (this.volume_animation.skip);

            base.destroy_backend ();
        }

        public void fade_in (int64           duration,
                             Pomodoro.Easing easing = Pomodoro.Easing.OUT)
        {
            if (!this.is_playing ()) {
                this.play ();
            }

            this.pending_fade_out_duration = 0;

            if (this.volume_animation.value_to != 1.0) {
                this.volume_animation.animate_to (1.0, duration, easing);
            }
        }

        public void fade_out (int64           duration,
                              Pomodoro.Easing easing = Pomodoro.Easing.IN)
        {
            if (this.volume_animation.value_to == 0.0) {
                return;
            }

            this.pending_fade_out_duration = 0;

            if (this.is_playing ()) {
                this.volume_animation.animate_to (0.0, duration, easing);
            }
            else {
                this.volume_animation.value = 0.0;
            }
        }

        /**
         * Fade-in to a specified `volume` and fade-out.
         */
        public void fade_in_out (int64  duration,
                                 double volume = 1.0)
                                 requires (duration > 0)
        {
            if (!this.is_playing ()) {
                this.play ();
            }

            if (this.volume_animation.value_to != volume)
            {
                this.pending_fade_out_duration = 2 * (duration / 3);
                this.pending_fade_out_easing = Pomodoro.Easing.IN_OUT;

                this.volume_animation.animate_to (volume, duration / 3, Pomodoro.Easing.OUT);
            }
            else {
                this.fade_out (duration, Pomodoro.Easing.IN_OUT);
            }
        }

        public override void dispose ()
        {
            if (this.volume_animation != null) {
                this.volume_animation.stop ();
                this.volume_animation = null;
            }

            base.dispose ();
        }
    }
}
