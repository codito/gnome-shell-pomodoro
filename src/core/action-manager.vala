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
    /**
     * Glue together actions storage with event bus and logger (for things related to actions).
     */
    [SingleInstance]
    public class ActionManager : GLib.Object
    {
        public Pomodoro.ActionListModel model { get; construct; }

        private Pomodoro.Logger?   logger = null;

        construct
        {
            this.model = new Pomodoro.ActionListModel ();
            this.model.action_added.connect (this.on_action_added);
            this.model.action_removed.connect (this.on_action_removed);
            this.model.action_replaced.connect (this.on_action_replaced);

            this.logger = new Pomodoro.Logger ();

            this.bind_actions ();
        }

        private void foreach_action (GLib.Func<Pomodoro.Action> func)
        {
            var model = this.model;
            var n_items = model.n_items;

            for (var position = 0U; position < n_items; position++) {
                func ((Pomodoro.Action) model.get_item (position));
            }
        }

        private void bind_action (Pomodoro.Action action)
        {
            action.notify["enabled"].connect (this.on_action_notify_enabled);

            var event_action = action as Pomodoro.EventAction;
            if (event_action != null) {
                event_action.triggered.connect (this.on_triggered);
            }

            var condition_action = action as Pomodoro.ConditionAction;
            if (condition_action != null) {
                condition_action.entered_condition.connect (this.on_entered_condition);
                condition_action.exited_condition.connect (this.on_exited_condition);
            }

            if (action.enabled) {
                action.bind ();
            }
        }

        private void unbind_action (Pomodoro.Action action)
        {
            action.notify["enabled"].disconnect (this.on_action_notify_enabled);

            var event_action = action as Pomodoro.EventAction;
            if (event_action != null) {
                event_action.triggered.disconnect (this.on_triggered);
            }

            var condition_action = action as Pomodoro.ConditionAction;
            if (condition_action != null) {
                condition_action.entered_condition.disconnect (this.on_entered_condition);
                condition_action.exited_condition.disconnect (this.on_exited_condition);
            }

            action.unbind ();
        }

        private void bind_actions ()
        {
            this.foreach_action (
                (action) => {
                    this.bind_action (action);
                });
        }

        private void unbind_actions ()
        {
            this.foreach_action (
                (action) => {
                    this.unbind_action (action);
                });
        }

        /**
         * We don't notify about validation errors
         */
        private void notify_action_failed (Pomodoro.Action           action,
                                           Pomodoro.CommandExecution execution,
                                           ulong                     entry_id)
        {
            var notification = new GLib.Notification (
                    _("Custom action \"%s\" has failed").printf (action.display_name));

            if (execution.error != null) {
                notification.set_body (execution.error.message);
            }

            notification.set_default_action_and_target_value (
                    "app.log",
                    new GLib.Variant.uint64 ((uint64) entry_id));

            // try {
            //     notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            // }
            // catch (GLib.Error error) {
            //     GLib.warning (error.message);
            // }

            GLib.Application.get_default ()?
                .send_notification (@"action:$(action.uuid)", notification);
        }

        private void watch_action_failed (Pomodoro.Action            action,
                                          Pomodoro.CommandExecution? execution,
                                          ulong                      entry_id)
        {
            if (execution == null) {
                return;
            }

            if (execution.error != null) {
                this.notify_action_failed (action, execution, entry_id);
            }
            else {
                execution.notify["error"].connect (
                    () => {
                        this.notify_action_failed (action, execution, entry_id);
                    });
            }
        }

        private void on_action_notify_enabled (GLib.Object    object,
                                               GLib.ParamSpec pspec)
        {
            var action = (Pomodoro.Action) object;

            // Sync settings attribute without doing full save
            action.settings.set_boolean ("enabled", action.enabled);

            if (action.enabled) {
                action.bind ();
            }
            else {
                action.unbind ();
            }

            // TODO: log action toggled
        }

        private void on_triggered (Pomodoro.EventAction       action,
                                   Pomodoro.Context           context,
                                   Pomodoro.CommandExecution? execution)
        {
            var entry_id = this.logger.log_action_triggered (action, context, execution);

            this.watch_action_failed (action, execution, entry_id);
        }

        private void on_entered_condition (Pomodoro.ConditionAction   action,
                                           Pomodoro.Context           context,
                                           Pomodoro.CommandExecution? execution)
        {
            var entry_id = this.logger.log_action_entered_condition (action, context, execution);

            this.watch_action_failed (action, execution, entry_id);
        }

        private void on_exited_condition (Pomodoro.ConditionAction   action,
                                          Pomodoro.Context           context,
                                          Pomodoro.CommandExecution? execution)
        {
            var entry_id = this.logger.log_action_exited_condition (action, context, execution);

            this.watch_action_failed (action, execution, entry_id);
        }

        private void on_action_added (Pomodoro.Action action)
        {
            this.bind_action (action);

            // TODO: log action added
        }

        private void on_action_removed (Pomodoro.Action action)
        {
            this.unbind_action (action);

            // TODO: log action removed

            GLib.Application.get_default ()?
                            .withdraw_notification (@"action:$(action.uuid)");
        }

        private void on_action_replaced (Pomodoro.Action action,
                                         Pomodoro.Action previous_action)
        {
            this.unbind_action (previous_action);
            this.bind_action (action);

            GLib.Application.get_default ()?
                            .withdraw_notification (@"action:$(previous_action.uuid)");
        }

        public override void dispose ()
        {
            if (this.model != null)
            {
                this.unbind_actions ();

                this.model.action_added.disconnect (this.on_action_added);
                this.model.action_removed.disconnect (this.on_action_removed);
                this.model.action_replaced.disconnect (this.on_action_replaced);
            }

            this.logger = null;

            base.dispose ();
        }
    }
}
