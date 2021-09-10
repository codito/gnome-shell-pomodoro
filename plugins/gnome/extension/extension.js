/*
 * A simple pomodoro timer for GNOME Shell
 *
 * Copyright (c) 2011-2023 gnome-pomodoro contributors
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
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import {Extension, gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {Indicator} from './indicator.js';
import {NotificationManager} from './notifications.js';
import {PomodoroExtensionService} from './dbus.js';
import {PresenceManager} from './presence.js';
import {ScreenShieldManager} from './screenShield.js';
import {Timer} from './timer.js';
import * as Config from './config.js';
import * as Utils from './utils.js';


const ExtensionMode = {
    DEFAULT: 0,
    RESTRICTED: 1,
};


export let extension = null;


export default class PomodoroExtension extends Extension {
    constructor(metadata) {
        super(metadata);

        this.settings              = null;
        this.pluginSettings        = null;
        this.timer                 = null;
        this.indicator             = null;
        this._notificationManager  = null;
        this.presenceManager       = null;
        this.mode                  = null;
        this.service               = null;
        this.keybinding            = false;
        this._sessionModeUpdatedId = 0;

        extension = this;
    }

    static getInstance() {
        return extension;
    }

    get application() {
        return Shell.AppSystem.get_default().lookup_app('org.gnomepomodoro.Pomodoro.desktop');
    }

    get notificationManager() {
        return this._notificationManager;
    }

    setMode(mode) {
        const previousMode = this.mode;
        const hideSystemNotifications = this.pluginSettings.get_boolean('hide-system-notifications');

        if (this.mode !== mode) {
            this.mode = mode;

            if (hideSystemNotifications)
                this._enablePresence();

            if (mode === ExtensionMode.RESTRICTED) {
                this._disableIndicator();
                this._disableNotificationManager();
                this._enableScreenShieldManager();
                this._enableKeybinding();
            } else {
                this._enableIndicator();
                this._enableNotificationManager(previousMode !== ExtensionMode.RESTRICTED);
                this._disableScreenShieldManager();
                this._enableKeybinding();
            }

            if (!hideSystemNotifications)
                this._disablePresence();
        }
    }

    _updateMode() {
        this.setMode(Main.sessionMode.isLocked ? ExtensionMode.RESTRICTED : ExtensionMode.DEFAULT);
    }

    _onSettingsChanged(settings, key) {
        switch (key) {
        case 'show-screen-notifications':
            if (this._notificationManager)
                this._notificationManager.useDialog = settings.get_boolean(key);

            break;

        case 'hide-system-notifications':
            if (settings.get_boolean(key))
                this._enablePresence();
            else
                this._disablePresence();

            break;

        case 'indicator-type':
            if (this.indicator)
                this.indicator.setType(settings.get_string(key));

            break;

        case 'blur-effect':
            if (this._notificationManager) {
                this._disableNotificationManager();
                this._enableNotificationManager(true);
            }
            break;
        }
    }

    _onServiceNameAcquired() {
    }

    _onServiceNameLost() {
        Utils.logWarning('Lost service name "org.gnomepomodoro.Pomodoro.Extension"');
    }

    _onTimerServiceConnected() {
        this.service.run();
        this._updateMode();
    }

    _onTimerServiceDisconnected() {
        Utils.logWarning('Lost connection to "org.gnomepomodoro.Pomodoro"');
        this._updateMode();
    }

    _onKeybindingPressed() {
        if (this.timer)
            this.timer.toggle();
    }

    _enableIndicator() {
        if (!this.indicator) {
            this.indicator = new Indicator(this.timer, this.pluginSettings.get_string('indicator-type'));
            this.indicator.connect('destroy', () => {
                this.indicator = null;
            });

            try {
                Main.panel.addToStatusArea(Config.PACKAGE_NAME, this.indicator);
            } catch (error) {
                Utils.logError(error);
            }
        } else {
            this.indicator.show();
        }
    }

    _disableIndicator() {
        if (this.indicator) {
            this.indicator.destroy();
            this.indicator = null;
        }
    }

    _enableKeybinding() {
        if (!this.keybinding) {
            this.keybinding = true;
            Main.wm.addKeybinding(
                'toggle-timer-key',
                this.settings,
                Meta.KeyBindingFlags.NONE,
                Shell.ActionMode.ALL,
                this._onKeybindingPressed.bind(this));
        }
    }

    _disableKeybinding() {
        if (this.keybinding) {
            this.keybinding = false;
            Main.wm.removeKeybinding('toggle-timer-key');
        }
    }

    _enablePresence() {
        if (!this.presenceManager)
            this.presenceManager = new PresenceManager(this.timer);
    }

    _disablePresence() {
        if (this.presenceManager) {
            this.presenceManager.destroy();
            this.presenceManager = null;
        }
    }

    _enableNotificationManager(animate) {
        if (!this._notificationManager) {
            const params = {
                useDialog: this.settings.get_boolean('show-screen-notifications'),
                animate,
            };
            this._notificationManager = new NotificationManager(this.timer, params);
        }
    }

    _disableNotificationManager() {
        if (this._notificationManager) {
            this._notificationManager.destroy();
            this._notificationManager = null;
        }
    }

    _enableScreenShieldManager() {
        if (!Main.screenShield)
            return;

        if (!this._screenShieldManager)
            this._screenShieldManager = new ScreenShieldManager(this.timer);
    }

    _disableScreenShieldManager() {
        if (this._screenShieldManager) {
            this._screenShieldManager.destroy();
            this._screenShieldManager = null;
        }
    }

    _connectSignals() {
        this._sessionModeUpdatedId = Main.sessionMode.connect('updated', () => this._updateMode());
    }

    _disconnectSignals() {
        if (this._sessionModeUpdatedId) {
            Main.sessionMode.disconnect(this._sessionModeUpdatedId);
            this._sessionModeUpdatedId = 0;
        }
    }

    // override method
    getSettings(schema) {
        const schemaDir = Gio.File.new_for_path(Config.GSETTINGS_SCHEMA_DIR);
        const defaultSource = Gio.SettingsSchemaSource.get_default();
        let schemaSource;
        if (schemaDir.query_exists(null))
            schemaSource = Gio.SettingsSchemaSource.new_from_directory(schemaDir.get_path(), defaultSource, false);
        else
            schemaSource = defaultSource;

        const schemaObj = schemaSource.lookup(schema, true);
        if (!schemaObj)
            throw new Error(`Schema ${schema} could not be found for extension ${this.uuid}. Please check your installation.`);

        return new Gio.Settings({settings_schema: schemaObj});
    }

    enable() {
        this.settings = this.getSettings('org.gnomepomodoro.pomodoro.preferences');
        this.settings.connect('changed::show-screen-notifications', this._onSettingsChanged.bind(this));

        this.pluginSettings = this.getSettings('org.gnomepomodoro.pomodoro.plugins.gnome');
        this.pluginSettings.connect('changed::hide-system-notifications', this._onSettingsChanged.bind(this));
        this.pluginSettings.connect('changed::indicator-type', this._onSettingsChanged.bind(this));
        this.pluginSettings.connect('changed::blur-effect', this._onSettingsChanged.bind(this));

        this.timer = new Timer();
        this.timer.connect('service-connected', this._onTimerServiceConnected.bind(this));
        this.timer.connect('service-disconnected', this._onTimerServiceDisconnected.bind(this));

        this.service = new PomodoroExtensionService();
        this.service.connect('name-acquired', this._onServiceNameAcquired.bind(this));
        this.service.connect('name-lost', this._onServiceNameLost.bind(this));

        this._updateMode();
        this._connectSignals();
    }

    disable() {
        this._disconnectSignals();

        this._disableKeybinding();
        this._disableScreenShieldManager();
        this._disableNotificationManager();
        this._disablePresence();
        this._disableIndicator();

        this.mode = null;

        this.service.destroy();
        this.service = null;

        this.timer.destroy();
        this.timer = null;

        this.pluginSettings.run_dispose();
        this.pluginSettings = null;

        this.settings.run_dispose();
        this.settings = null;
    }
}
