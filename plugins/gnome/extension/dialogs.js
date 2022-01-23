/*
 * Copyright (c) 2011-2021 gnome-pomodoro contributors
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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

const Signals = imports.signals;

const { Atk, Clutter, GLib, GObject, Meta, Shell, St, Pango } = imports.gi;

const Layout = imports.ui.layout;
const Lightbox = imports.ui.lightbox;
const Main = imports.ui.main;

const Params = imports.misc.params;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


/* Time between user input events before making dialog modal.
 * Value is a little higher than:
 *   - slow typing speed of 23 words per minute which translates
 *     to 523 miliseconds between key presses
 *   - moderate typing speed of 35 words per minute, 343 miliseconds.
 */
const IDLE_TIME_TO_PUSH_MODAL = 600;
const PUSH_MODAL_TIME_LIMIT = 1000;
const PUSH_MODAL_RATE = 60;
const MOTION_DISTANCE_TO_CLOSE = 20;

const IDLE_TIME_TO_OPEN = 60000;
const IDLE_TIME_TO_CLOSE = 600;
const MIN_DISPLAY_TIME = 500;

const FADE_IN_TIME = 300;
const FADE_OUT_TIME = 300;

const BLUR_BRIGHTNESS = 0.4;
const BLUR_SIGMA = 20.0;

const OPEN_WHEN_IDLE_MIN_REMAINING_TIME = 3.0;

const DEFAULT_BACKGROUND_COLOR = Clutter.Color.from_pixel(0x000000ff);

var State = {
    OPENED: 0,
    CLOSED: 1,
    OPENING: 2,
    CLOSING: 3
};


var BlurredLightbox = GObject.registerClass(
class PomodoroBlurredLightbox extends Lightbox.Lightbox {
    _init(container, params) {
        params = Params.parse(params, {
            inhibitEvents: false,
            width: null,
            height: null,
        });

        super._init(container, {
            inhibitEvents: params.inhibitEvents,
            width: params.width,
            height: params.height,
            fadeFactor: 1.0,
            radialEffect: false,
        });

        if (Clutter.feature_available(Clutter.FeatureFlags.SHADERS_GLSL)) {
            // Clone the group that contains all of UI on the screen. This is the
            // chrome, the windows, etc.
            this._uiGroup = new Clutter.Clone({ source: Main.uiGroup, clip_to_allocation: true });
            this._uiGroup.set_background_color(DEFAULT_BACKGROUND_COLOR);
            this._uiGroup.add_effect_with_name('blur', new Shell.BlurEffect());
            this.set_child(this._uiGroup);

            this.set({ opacity: 0, style_class: 'extension-pomodoro-lightbox-blurred' });
        }
        else {
            this._uiGroup = null;

            this.set({ opacity: 0, style_class: 'extension-pomodoro-lightbox' });
        }

        let themeContext = St.ThemeContext.get_for_stage(global.stage);
        this._scaleChangedId = themeContext.connect('notify::scale-factor', this._updateEffects.bind(this));
        this._monitorsChangedId = Main.layoutManager.connect('monitors-changed', this._updateEffects.bind(this));

        this._updateEffects();
    }

    _updateEffects() {
        if (this._uiGroup) {
            const themeContext = St.ThemeContext.get_for_stage(global.stage);
            let effect = this._uiGroup.get_effect('blur');

            if (effect) {
                effect.set({
                    brightness: BLUR_BRIGHTNESS,
                    sigma: BLUR_SIGMA * themeContext.scale_factor,
                });
                effect.queue_repaint();
            }
        }
    }

    lightOn(fadeInTime) {
        super.lightOn(fadeInTime);

        if (this._uiGroup && !Utils.versionCheck('40.0')) {  // TODO remove compatibility for 3.38
            let effect = this._uiGroup.get_effect('blur');
            if (effect) {
                effect.set({
                    brightness: BLUR_BRIGHTNESS * 0.99,
                });
            }

            // HACK: force effect to be repaint itself during fading-in
            // in theory effect.queue_repaint(); should be enough
            this._uiGroup.ease_property('@effects.blur.brightness', BLUR_BRIGHTNESS, {
                duration: fadeInTime || 0,
            });
        }
    }

    lightOff(fadeOutTime) {
        super.lightOff(fadeOutTime);

        if (this._uiGroup && !Utils.versionCheck('40.0')) {  // TODO remove compatibility for 3.38
            let effect = this._uiGroup.get_effect('blur');
            if (effect) {
                // HACK: force effect to be repaint itself during fading-out
                // in theory effect.queue_repaint(); should be enough
                this._uiGroup.ease_property('@effects.blur.brightness', BLUR_BRIGHTNESS * 0.99, {
                    duration: fadeOutTime || 0,
                });
            }
        }
    }

    /* override parent method */
    _onDestroy() {
        if (this._monitorsChangedId) {
            Main.layoutManager.disconnect(this._monitorsChangedId);
            delete this._monitorsChangedId;
        }

        let themeContext = St.ThemeContext.get_for_stage(global.stage);
        if (this._scaleChangedId) {
            themeContext.disconnect(this._scaleChangedId);
            delete this._scaleChangedId;
        }

        super._onDestroy();
    }
});


/**
 * ModalDialog class based on ModalDialog from GNOME Shell. We need our own
 * class to have more event signals, different fade in/out times, and different
 * event blocking behavior.
 */
var ModalDialog = GObject.registerClass({
    Properties: {
        'state': GObject.ParamSpec.int('state', 'Dialog state', 'state',
                                       GObject.ParamFlags.READABLE,
                                       Math.min(...Object.values(State)),
                                       Math.max(...Object.values(State)),
                                       State.CLOSED),
    },
    Signals: { 'opened': {}, 'opening': {}, 'closed': {}, 'closing': {} },
}, class PomodoroModalDialog extends St.Widget {
    _init() {
        super._init({ style_class: 'extension-pomodoro-dialog',
                      accessible_role: Atk.Role.DIALOG,
                      layout_manager: new Clutter.BinLayout(),
                      reactive: false,
                      visible: false,
                      opacity: 0 });

        this._state = State.CLOSED;
        this._hasModal = false;
        this._pushModalDelaySource = 0;
        this._pushModalWatchId = 0;
        this._pushModalSource = 0;
        this._keyFocusOutId = 0;
        this._monitorConstraint = new Layout.MonitorConstraint();
        this._monitorConstraint.primary = true;
        this._stageConstraint = new Clutter.BindConstraint({
                                       source: global.stage,
                                       coordinate: Clutter.BindCoordinate.ALL });
        this.add_constraint(this._stageConstraint);

        if (global.backend.get_core_idle_monitor !== undefined) {
            this._idleMonitor = global.backend.get_core_idle_monitor();
        }
        else {
            this._idleMonitor = Meta.IdleMonitor.get_core();  // TODO: remove along support for gnome-shell 40
        }

        this.connect('destroy', this._onDestroy.bind(this));

        // Modal dialogs are fixed width and grow vertically; set the request
        // mode accordingly so wrapped labels are handled correctly during
        // size requests.
        this._layout = new St.Widget({ layout_manager: new Clutter.BinLayout() });
        this._layout.add_constraint(this._monitorConstraint);
        this.add_actor(this._layout);

        // Lightbox will be a direct child of the ModalDialog
        this._lightbox = new BlurredLightbox(this,
                                             { inhibitEvents: false });
        this._lightbox.highlight(this._layout);

        global.stage.add_actor(this);
        global.focus_manager.add_group(this._lightbox);
    }

    get state() {
        return this._state;
    }

    _setState(state) {
        if (this._state == state) {
            return;
        }

        this._state = state;
        this.notify('state');
    }

    _raiseMessageTray() {
        let messageTray = Main.messageTray;

        messageTray.ref();

        Main.layoutManager.removeChrome(messageTray);

        global.stage.add_child(messageTray);

        messageTray.bannerBlocked = false;
        messageTray.unref();
    }

    _lowerMessageTray() {
        let messageTray = Main.messageTray;

        messageTray.ref();

        global.stage.remove_child(messageTray);

        Main.layoutManager.addChrome(messageTray, { affectsInputRegion: false });

        messageTray.unref();
    }

    _onKeyFocusOut() {
        let focus = global.stage.key_focus;

        if (focus === null || !this._lightbox.contains(focus)) {
            this.close(true);
        }
    }

    _onOpenComplete() {
        this._setState(State.OPENED);
        this.emit('opened');
    }

    _onIdleMonitorBecameIdle(monitor) {
        let pushModalTries = 0;
        let timestamp = global.get_current_time();

        if (this._pushModalWatchId) {
            this._idleMonitor.remove_watch(this._pushModalWatchId);
            this._pushModalWatchId = 0;
        }

        if (this.pushModal(timestamp)) {
            return GLib.SOURCE_REMOVE;
        }

        this._pushModalSource = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            Math.floor(1000 / PUSH_MODAL_RATE),
            () => {
                pushModalTries += 1;

                if (this.pushModal(timestamp)) {
                    this._pushModalSource = 0;
                    return GLib.SOURCE_REMOVE;  // success
                }

                if (pushModalTries > PUSH_MODAL_TIME_LIMIT * PUSH_MODAL_RATE) {
                    this.close(true);
                    this._pushModalSource = 0;
                    return GLib.SOURCE_REMOVE;  // failure
                }

                return GLib.SOURCE_CONTINUE;
            });
        GLib.Source.set_name_by_id(this._pushModalSource,
                                   '[gnome-pomodoro] this._pushModalSource');
    }

    // Gradually open the dialog. Try to make it modal once user had chance to see it.
    open(animate) {
        if (this.state == State.OPENED || this.state == State.OPENING) {
            return;
        }

        this._pushModalDelaySource = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            Math.max(MIN_DISPLAY_TIME - IDLE_TIME_TO_PUSH_MODAL, 0),
            () => {
                if (this._pushModalWatchId == 0) {
                    this._pushModalWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_PUSH_MODAL,
                                                                              this._onIdleMonitorBecameIdle.bind(this));
                }

                this._pushModalDelaySource = 0;

                return GLib.SOURCE_REMOVE;
            }
        );
        GLib.Source.set_name_by_id(this._pushModalDelaySource,
                                   '[gnome-pomodoro] this._pushModalDelaySource');

        global.stage.set_child_above_sibling(this, null);

        this.remove_all_transitions();
        this.show();
        this._raiseMessageTray();
        this._setState(State.OPENING);
        this.emit('opening');

        if (animate) {
            this._lightbox.lightOn(FADE_IN_TIME);

            this.ease({
                opacity: 255,
                duration: FADE_IN_TIME,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: this._onOpenComplete.bind(this),
            });
        }
        else {
            this._lightbox.lightOn();
            this.opacity = 255;
            this._onOpenComplete();
        }
    }

    _onCloseComplete() {
        this.hide();
        this._lowerMessageTray();
        this._setState(State.CLOSED);
        this.emit('closed');
    }

    close(animate) {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return;
        }

        this.popModal();
        this._setState(State.CLOSING);
        this.emit('closing');

        this.remove_all_transitions();

        if (animate) {
            this._lightbox.lightOff(FADE_OUT_TIME);
            this.ease({
                opacity: 0,
                duration: FADE_OUT_TIME,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: this._onCloseComplete.bind(this),
            });
        } else {
            this._lightbox.lightOff();
            this.opacity = 0;
            this._onCloseComplete();
        }
    }

    _disconnectPushModalSignals() {
        if (this._pushModalDelaySource) {
            GLib.source_remove(this._pushModalDelaySource);
            this._pushModalDelaySource = 0;
        }

        if (this._pushModalSource) {
            GLib.source_remove(this._pushModalSource);
            this._pushModalSource = 0;
        }

        if (this._pushModalWatchId) {
            this._idleMonitor.remove_watch(this._pushModalWatchId);
            this._pushModalWatchId = 0;
        }
    }

    // Drop modal status without closing the dialog; this makes the
    // dialog insensitive as well, so it needs to be followed shortly
    // by either a close() or a pushModal()
    popModal(timestamp) {
        this._disconnectPushModalSignals();

        if (this._keyFocusOutId) {
            this._lightbox.disconnect(this._keyFocusOutId);
            this._keyFocusOutId = 0;
        }

        if (!this._hasModal) {
            return;
        }

        Main.popModal(this, timestamp);
        this._hasModal = false;
        this._lightbox.reactive = false;
    }

    pushModal(timestamp) {
        if (this._hasModal) {
            return true;
        }

        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return false;
        }

        let params = { actionMode: Shell.ActionMode.SYSTEM_MODAL };
        if (timestamp) {
            params['timestamp'] = timestamp;
        }

        if (!Main.pushModal(this, params)) {
            return;
        }

        this._disconnectPushModalSignals();
        this._hasModal = true;
        this._lightbox.reactive = true;

        global.stage.set_key_focus(this._lightbox);

        if (!this._keyFocusOutId) {
            this._keyFocusOutId = this._lightbox.connect('key-focus-out', this._onKeyFocusOut.bind(this));
        }

        Main.layoutManager.emit('system-modal-opened');
    }

    _onDestroy() {
        this.popModal();

        if (this._lightbox) {
            this._lightbox.destroy();
            this._lightbox = null;
        }
    }
});


var PomodoroEndDialog = GObject.registerClass(
class PomodoroEndDialog extends ModalDialog {
    _init(timer) {
        super._init();

        this.timer = timer;
        this.description = _("It's time to take a break");

        this._openWhenIdleWatchId        = 0;
        this._closeWhenActiveDelaySource = 0;
        this._closeWhenActiveIdleWatchId = 0;
        this._mappedId                   = 0;
        this._timerUpdateId              = 0;
        this._eventId                    = 0;
        this._styleChangedId             = 0;
        this._closingId                  = 0;

        this._minutesLabel = new St.Label({
            x_expand: true,
            x_align: Clutter.ActorAlign.END,
        });
        this._separatorLabel = new St.Label({
            text: ":",
        });
        this._secondsLabel = new St.Label({
            x_expand: true,
            x_align: Clutter.ActorAlign.START,
        });

        let hbox = new St.BoxLayout({ vertical: false, style_class: 'extension-pomodoro-dialog-timer' });
        hbox.add_actor(this._minutesLabel);
        hbox.add_actor(this._separatorLabel);
        hbox.add_actor(this._secondsLabel);

        this._descriptionLabel = new St.Label({
            style_class: 'extension-pomodoro-dialog-description',
            text: this.description,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._descriptionLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._descriptionLabel.clutter_text.line_wrap = true;

        let box = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog-box',
                                     vertical: true });
        box.add_actor(hbox);
        box.add_actor(this._descriptionLabel);
        this._layout.add_actor(box);

        this._mappedId = this.connect('notify::mapped', this._onMappedChanged.bind(this));
        this._closingId = this.connect('closing', this._onClosing.bind(this));
    }

    _onMappedChanged() {
        if (this.mapped) {
            if (!this._styleChangedId) {
                this._styleChangedId = this._secondsLabel.connect('style-changed', this._onStyleChanged.bind(this));
                this._onStyleChanged(this._secondsLabel);
            }
            if (!this._timerUpdateId) {
                this._timerUpdateId = this.timer.connect('update', this._onTimerUpdate.bind(this));
                this._onTimerUpdate();
            }
        }
        else {
            if (this._styleChangedId) {
                this._secondsLabel.disconnect(this._styleChangedId);
                this._styleChangedId = 0;
            }
            if (this._timerUpdateId) {
                this.timer.disconnect(this._timerUpdateId);
                this._timerUpdateId = 0;
            }
        }
    }

    _onStyleChanged(actor) {
        let themeNode = actor.get_theme_node();
        let font      = themeNode.get_font();
        let context   = actor.get_pango_context();
        let metrics   = context.get_metrics(font, context.get_language());
        let digitWidth = metrics.get_approximate_digit_width() / Pango.SCALE;

        this._secondsLabel.natural_width = 2 * digitWidth;
    }

    _onTimerUpdate() {
        if (this.timer.isBreak()) {
            let remaining = Math.max(this.timer.getRemaining(), 0.0);
            let minutes   = Math.floor(remaining / 60);
            let seconds   = Math.floor(remaining % 60);

            // method may be called while label actor got destroyed
            if (this._minutesLabel.clutter_text) {
                this._minutesLabel.clutter_text.set_text('%d'.format(minutes));
            }
            if (this._secondsLabel.clutter_text) {
                this._secondsLabel.clutter_text.set_text('%02d'.format(seconds));
            }
        }
    }

    // disconecct signals that are no longer neeeded after dialog closes
    _disconnectSignals() {
        if (this._openWhenIdleWatchId) {
            this._idleMonitor.remove_watch(this._openWhenIdleWatchId);
            this._openWhenIdleWatchId = 0;
        }

        if (this._eventId) {
            this._lightbox.disconnect(this._eventId);
            this._eventId = 0;
        }

        if (this._closeWhenActiveDelaySource) {
            GLib.source_remove(this._closeWhenActiveDelaySource);
            this._closeWhenActiveDelaySource = 0;
        }

        if (this._closeWhenActiveIdleWatchId) {
            this._idleMonitor.remove_watch(this._closeWhenActiveIdleWatchId);
            this._closeWhenActiveIdleWatchId = 0;
        }

        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        if (this._styleChangedId) {
            this._secondsLabel.disconnect(this._styleChangedId);
            this._styleChangedId = 0;
        }
    }

    _onEvent(actor, event) {
        let x, y, dx, dy, distance;

        if (!event.get_device()) {
            return Clutter.EVENT_STOP;
        }

        switch (event.type())
        {
            case Clutter.EventType.ENTER:
            case Clutter.EventType.LEAVE:
            case Clutter.EventType.STAGE_STATE:
            case Clutter.EventType.DESTROY_NOTIFY:
            case Clutter.EventType.CLIENT_MESSAGE:
            case Clutter.EventType.DELETE:
                return Clutter.EVENT_PROPAGATE;

            case Clutter.EventType.MOTION:
                [x, y]   = event.get_coords();
                dx       = this._eventX >= 0 ? x - this._eventX : 0;
                dy       = this._eventY >= 0 ? y - this._eventY : 0;
                distance = dx * dx + dy * dy;

                this._eventX = x;
                this._eventY = y;

                if (distance > MOTION_DISTANCE_TO_CLOSE * MOTION_DISTANCE_TO_CLOSE) {
                    this.close(true);
                }

                break;

            case Clutter.EventType.KEY_PRESS:
                switch (event.get_key_symbol())
                {
                    case Clutter.KEY_AudioCycleTrack:
                    case Clutter.KEY_AudioForward:
                    case Clutter.KEY_AudioLowerVolume:
                    case Clutter.KEY_AudioNext:
                    case Clutter.KEY_AudioPause:
                    case Clutter.KEY_AudioPlay:
                    case Clutter.KEY_AudioPrev:
                    case Clutter.KEY_AudioRaiseVolume:
                    case Clutter.KEY_AudioRandomPlay:
                    case Clutter.KEY_AudioRecord:
                    case Clutter.KEY_AudioRepeat:
                    case Clutter.KEY_AudioRewind:
                    case Clutter.KEY_AudioStop:
                    case Clutter.KEY_AudioMicMute:
                    case Clutter.KEY_AudioMute:
                    case Clutter.KEY_MonBrightnessDown:
                    case Clutter.KEY_MonBrightnessUp:
                    case Clutter.KEY_Display:
                        return Clutter.EVENT_PROPAGATE;

                    default:
                        this.close(true);
                        break;
                }

                break;

            case Clutter.EventType.BUTTON_PRESS:
            case Clutter.EventType.TOUCH_BEGIN:
                this.close(true);
                break;
        }

        return Clutter.EVENT_STOP;
    }

    _onClosing() {
        this._disconnectSignals();
    }

    _onDestroy() {
        this._disconnectSignals()

        if (this._closingId) {
            this.disconnect(this._closingId);
            this._closingId = 0;
        }

        if (this._actorMappedId) {
            this.disconnect(this._actorMappedId);
            this._actorMappedId = 0;
        }

        super._onDestroy();
    }

    _closeWhenActive() {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return;
        }

        if (this._eventId == 0) {
            this._eventX = -1;
            this._eventY = -1;
            this._eventId = this._lightbox.connect('event', this._onEvent.bind(this));
        }
    }

    // Open the dialog. Wait until user had chance of seeing the dialog
    // and schedule to close it once user becomes active.
    open(animate) {
        super.open(animate);

        if (this._closeWhenActiveDelaySource == 0) {
            this._closeWhenActiveDelaySource = GLib.timeout_add(
                GLib.PRIORITY_DEFAULT,
                MIN_DISPLAY_TIME,
                () => {
                    if (this._idleMonitor.get_idletime() < IDLE_TIME_TO_CLOSE) {
                        this._closeWhenActiveIdleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_CLOSE,
                            (monitor) => this._closeWhenActive()
                        );
                    }
                    else {
                        this._closeWhenActive();
                    }

                    this._closeWhenActiveDelaySource = 0;
                    return GLib.SOURCE_REMOVE;
                });
            GLib.Source.set_name_by_id(this._closeWhenActiveDelaySource,
                                       '[gnome-pomodoro] this._closeWhenActiveDelaySource');
        }
    }

    // Schedule dialog to open when idle
    openWhenIdle() {
        if (this.state == State.OPEN || this.state == State.OPENING) {
            return;
        }

        if (this._openWhenIdleWatchId == 0) {
            this._openWhenIdleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_OPEN,
                (monitor) => {
                    let info = Utils.getFocusedWindowInfo();

                    if (info.isPlayer && info.isFullscreen)
                    {
                        // dont reopen if playing a video
                        return;
                    }

                    if (!this.timer.isBreak() ||
                        this.timer.getRemaining() < OPEN_WHEN_IDLE_MIN_REMAINING_TIME)
                    {
                        return;
                    }

                    this.open(true);
                });
        }
    }

    setDescription(text) {
        this.description = text;

        if (this._descriptionLabel.clutter_text) {
            this._descriptionLabel.clutter_text.set_text(this.description);
        }
    }
});
