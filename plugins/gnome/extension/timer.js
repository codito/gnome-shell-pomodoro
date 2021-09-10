/*
 * Copyright (c) 2014-2016 gnome-pomodoro contributors
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
 */

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import Pango from 'gi://Pango';
import St from 'gi://St';

import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import {EventEmitter} from 'resource:///org/gnome/shell/misc/signals.js';
import * as Params from 'resource:///org/gnome/shell/misc/params.js';

import {PomodoroClient} from './dbus.js';
import {IssueNotification} from './notifications.js';
import * as Config from './config.js';
import * as Utils from './utils.js';


export const State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    SHORT_BREAK: 'short-break',
    LONG_BREAK: 'long-break',

    label(state) {
        switch (state) {
        case State.POMODORO:
            return _('Pomodoro');

        case State.SHORT_BREAK:
            return _('Short Break');

        case State.LONG_BREAK:
            return _('Long Break');

        default:
            return null;
        }
    },
};


export class Timer extends EventEmitter {
    constructor() {
        super();

        this._connected = false;
        this._state = null;
        this._isPaused = null;
        this._stateDuration = 0;
        this._propertiesChangedId = 0;
        this._elapsed = 0.0;

        this._proxy = PomodoroClient(this._onInit.bind(this));

        this._propertiesChangedId = this._proxy.connect(
            'g-properties-changed',
            this._onPropertiesChanged.bind(this));

        this._nameWatcherId = Gio.DBus.session.watch_name(
            'org.gnomepomodoro.Pomodoro',
            Gio.BusNameWatcherFlags.AUTO_START,
            this._onNameAppeared.bind(this),
            this._onNameVanished.bind(this));
    }

    _onNameAppeared() {
        this._connected = true;

        this.emit('service-connected');
        this.emit('update');
    }

    _onNameVanished() {
        this._connected = false;

        this.emit('update');
        this.emit('service-disconnected');
    }

    _onPropertiesChanged(proxy, properties) {  // eslint-disable-line no-unused-vars
        const state = proxy.State;
        const stateDuration = proxy.StateDuration;
        const elapsed = proxy.Elapsed;
        const isPaused = proxy.IsPaused;

        if (this._state !== state || this._stateDuration !== stateDuration || this._elapsed > elapsed) {
            this._state = state;
            this._stateDuration = stateDuration;
            this._elapsed = elapsed;

            this.emit('state-changed');
        } else {
            this._elapsed = elapsed;
        }

        if (this._isPaused !== isPaused) {
            this._isPaused = isPaused;
            this.emit(isPaused ? 'paused' : 'resumed');
        }

        this.emit('update');
    }

    _onInit(proxy, error) {
        if (error) {
            Utils.logWarning(error.message);
            this._notifyServiceNotInstalled();
        }
    }

    _onCallback(result, error) {
        if (error) {
            Utils.logWarning(error.message);

            if (error.matches(Gio.DBusError, Gio.DBusError.SERVICE_UNKNOWN))
                this._notifyServiceNotInstalled();
        }
    }

    getState() {
        if (!this._connected || this._proxy.State === null)
            return State.NULL;


        return this._proxy.State;
    }

    setState(state, timestamp) {
        this._proxy.SetStateRemote(
            state,
            timestamp || 0,
            this._onCallback.bind(this));
    }

    getStateDuration() {
        return this._proxy.StateDuration;
    }

    setStateDuration(duration) {
        this._proxy.SetStateDurationRemote(
            this._proxy.State,
            duration,
            this._onCallback.bind(this));
    }

    get stateDuration() {
        return this._proxy.StateDuration;
    }

    set stateDuration(value) {
        this._proxy.SetStateDurationRemote(
            this._proxy.State,
            value,
            this._onCallback.bind(this));
    }

    getElapsed() {
        return this._proxy.Elapsed;
    }

    getRemaining() {
        let state = this.getState();

        if (state === State.NULL)
            return 0.0;


        return Math.ceil(this._proxy.StateDuration - this._proxy.Elapsed);
    }

    getProgress() {
        return this._connected && this._proxy.StateDuration > 0
            ? this._proxy.Elapsed / this._proxy.StateDuration
            : 0.0;
    }

    isPaused() {
        return this._connected && this._proxy.IsPaused;
    }

    start() {
        this._proxy.StartRemote(this._onCallback.bind(this));
    }

    stop() {
        this._proxy.StopRemote(this._onCallback.bind(this));
    }

    pause() {
        this._proxy.PauseRemote(this._onCallback.bind(this));
    }

    resume() {
        this._proxy.ResumeRemote(this._onCallback.bind(this));
    }

    skip() {
        this._proxy.SkipRemote(this._onCallback.bind(this));
    }

    reset() {
        this._proxy.ResetRemote(this._onCallback.bind(this));
    }

    toggle() {
        if (this.getState() === State.NULL)
            this.start();
        else
            this.stop();
    }

    isBreak() {
        const state = this.getState();

        return state === State.SHORT_BREAK || state === State.LONG_BREAK;
    }

    showMainWindow(mode, timestamp) {
        this._proxy.ShowMainWindowRemote(mode, timestamp, this._onCallback.bind(this));
    }

    showPreferences(timestamp) {
        this._proxy.ShowPreferencesRemote(timestamp, this._onCallback.bind(this));
    }

    quit() {
        this._proxy.QuitRemote((result, error) => {  // eslint-disable-line no-unused-vars
            Utils.disableExtension(Config.EXTENSION_UUID);
        });
    }

    _notifyServiceNotInstalled() {
        const notification = new IssueNotification(_('Failed to run <i>%s</i> service').format(Config.PACKAGE_NAME));
        notification.show();
    }

    destroy() {
        if (this._propertiesChangedId) {
            this._proxy.disconnect(this._propertiesChangedId);
            this._propertiesChangedId = 0;
        }

        if (this._nameWatcherId) {
            Gio.DBus.session.unwatch_name(this._nameWatcherId);
            this._nameWatcherId = 0;
        }
    }
}


const MonospaceLabel = GObject.registerClass({
    Properties: {
        'text': GObject.ParamSpec.string('text', '', '',
            GObject.ParamFlags.READWRITE,
            ''),
        'text-align': GObject.ParamSpec.enum('text-align', '', '',
            GObject.ParamFlags.READWRITE,
            Pango.Alignment, Pango.Alignment.LEFT),
    },
}, class PomodoroMonospaceLabel extends St.Widget {
    _init(params) {
        params = Params.parse(params, {
            style_class: 'extension-pomodoro-monospace-label',
            layout_manager: new Clutter.BinLayout(),
        }, true);

        super._init(params);

        this._digitWidth = 0.0;
        this._styleChangedId = 0;
        this._notifyTextAlignId = 0;

        this._label = new St.Label({
            x_expand: true,
            y_expand: true,
            y_align: Clutter.ActorAlign.FILL,
        });
        this._label.clutter_text.line_wrap = false;
        this._label.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this.add_child(this._label);

        this.bind_property('text', this._label, 'text', GObject.BindingFlags.SYNC_CREATE);

        this._styleChangedId = this.connect('style-changed', this._onStyleChanged.bind(this));
        this._notifyTextAlignId = this.connect('notify::text-align', this._onNotifyTextAlign.bind(this));
        this.connect('destroy', this._onDestroy.bind(this));

        this._onStyleChanged();
        this._onNotifyTextAlign();
    }

    // eslint-disable-next-line no-unused-vars
    vfunc_get_preferred_width(forHeight) {
        const themeNode = this.get_theme_node();

        if (this._digitWidth === 0.0) {
            const font      = themeNode.get_font();
            const context   = this.get_pango_context();
            const metrics   = context.get_metrics(font, context.get_language());

            this._digitWidth = metrics.get_approximate_digit_width() / Pango.SCALE;
        }

        const naturalWidth = Math.ceil(this.text.length * this._digitWidth);

        return themeNode.adjust_preferred_width(naturalWidth, naturalWidth);
    }

    _onStyleChanged() {
        this._digitWidth = 0.0;
    }

    _onNotifyTextAlign() {
        // St.Label doesn't support text-align through css, so alignment is done through allocation.
        switch (this.text_align) {
        case Pango.Alignment.LEFT:
            this._label.x_align = Clutter.ActorAlign.START;
            break;

        case Pango.Alignment.CENTER:
            this._label.x_align = Clutter.ActorAlign.CENTER;
            break;

        case Pango.Alignment.RIGHT:
            this._label.x_align = Clutter.ActorAlign.END;
            break;
        }
    }

    _onDestroy() {
        if (this._styleChangedId) {
            this.disconnect(this._styleChangedId);
            this._styleChangedId = 0;
        }

        if (this._notifyTextAlignId) {
            this.disconnect(this._notifyTextAlignId);
            this._notifyTextAlignId = 0;
        }
    }
});


// Label widget that for longer text behaves like a normal label, but for short text
// behaves like a monospace label.
const SemiMonospaceLabel = GObject.registerClass(
class PomodoroSemiMonospaceLabel extends MonospaceLabel {
    vfunc_get_preferred_width(forHeight) {
        const themeNode = this.get_theme_node();

        if (this.text.length > 1) {
            const [minimumWidth, naturalWidth] = this._label.get_preferred_width(-1);

            return themeNode.adjust_preferred_width(minimumWidth, naturalWidth);
        } else {
            return super.vfunc_get_preferred_width(forHeight);
        }
    }
});


export const TimerLabel = GObject.registerClass(
class PomodoroTimerLabel extends St.BoxLayout {
    _init(timer, params) {
        params = Params.parse(params, {
            style_class: 'extension-pomodoro-timer-label',
            vertical: false,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: false,
            y_expand: false,
            reactive: false,
            can_focus: false,
            track_hover: false,
        }, true);

        super._init(params);

        this._timer = timer;
        this._timerState = null;
        this._timerUpdateId = 0;

        this._minutesLabel = new SemiMonospaceLabel({
            text: '0',
            text_align: Pango.Alignment.RIGHT,
        });
        this.add_actor(this._minutesLabel);

        this._separatorLabel = new St.Label({
            text: ':',
        });
        this._separatorLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this.add_actor(this._separatorLabel);

        this._secondsLabel = new MonospaceLabel({
            text: '00',
            text_align: Pango.Alignment.LEFT,
        });
        this.add_actor(this._secondsLabel);

        this.connect('destroy', this._onDestroy.bind(this));
    }

    freeze() {
        this._timerState = this._timer.getState();
    }

    unfreeze() {
        this._timerState = null;
    }

    vfunc_map() {
        if (!this._timerUpdateId)
            this._timerUpdateId = this._timer.connect('update', this._onTimerUpdate.bind(this));

        this._updateLabels();

        super.vfunc_map();
    }

    vfunc_unmap() {
        if (this._timerUpdateId) {
            this._timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        super.vfunc_unmap();
    }

    _updateLabels() {
        if (this._timerState && this._timerState !== this._timer.getState())
            return;

        const remaining = Math.max(Math.round(this._timer.getRemaining()), 0);
        const minutes   = Math.floor(remaining / 60);
        const seconds   = remaining - 60 * minutes;

        this._minutesLabel.text = '%d'.format(minutes);
        this._secondsLabel.text = '%02d'.format(seconds);
    }

    _onTimerUpdate() {
        this._updateLabels();
    }

    _onDestroy() {
        if (this._timerUpdateId) {
            this._timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    }
});
