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


namespace Actions
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/plugins/actions/action-page.ui")]
    public class ActionPage : Gtk.Box, Pomodoro.PreferencesPage
    {
        [GtkChild]
        private unowned Gtk.Entry name_entry;
        [GtkChild]
        private unowned Gtk.Entry command_entry;
        [GtkChild]
        private unowned Gtk.ToggleButton pomodoro_state_togglebutton;
        [GtkChild]
        private unowned Gtk.ToggleButton short_break_state_togglebutton;
        [GtkChild]
        private unowned Gtk.ToggleButton long_break_state_togglebutton;
        [GtkChild]
        private unowned Gtk.CheckButton start_trigger_checkbutton;
        [GtkChild]
        private unowned Gtk.CheckButton complete_trigger_checkbutton;
        [GtkChild]
        private unowned Gtk.CheckButton skip_trigger_checkbutton;
        [GtkChild]
        private unowned Gtk.CheckButton pause_trigger_checkbutton;
        [GtkChild]
        private unowned Gtk.CheckButton resume_trigger_checkbutton;
        [GtkChild]
        private unowned Gtk.CheckButton enable_trigger_checkbutton;
        [GtkChild]
        private unowned Gtk.CheckButton disable_trigger_checkbutton;
        [GtkChild]
        private unowned Gtk.MenuButton add_variable_button;

        private Actions.Action action;
        private GLib.List<GLib.Binding> bindings;

        construct
        {
            var action_group = new GLib.SimpleActionGroup ();

            var add_variable_action = new GLib.SimpleAction ("add-variable", GLib.VariantType.STRING);
            add_variable_action.activate.connect (this.activate_add_variable);
            action_group.add_action (add_variable_action);

            this.insert_action_group ("page", action_group);

            try {
                var menu_builder = new Gtk.Builder ();
                menu_builder.add_from_resource ("/org/gnomepomodoro/Pomodoro/plugins/actions/menus.ui");

                var add_variable_model = menu_builder.get_object ("add-variable") as GLib.MenuModel;
                var add_variable_popover = new Gtk.Popover.from_model (this.add_variable_button,
                                                                       add_variable_model);
                this.add_variable_button.popover = add_variable_popover;
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }
        }

        public virtual void configure_header_bar (Gtk.HeaderBar header_bar)
        {
        }

        /**
         * Remove action if leaving with empty name
         */
        public override void unmap ()
        {
            base.unmap ();

            if (this.action.name == "") {
                Actions.ActionManager.get_instance ().remove (this.action);
            }
        }

        public void set_action (Actions.Action action)
        {
            foreach (var binding in this.bindings) {
                binding.unbind ();
            }

            this.action = action;

            this.bindings.append (
                this.action.bind_property ("name",
                                           this.name_entry,
                                           "text",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL));
            this.bindings.append (
                this.action.bind_property ("command",
                                           this.command_entry,
                                           "text",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL));
            this.bindings.append (
                this.action.bind_property ("command-valid",
                                           this.command_entry,
                                           "secondary-icon-name",
                                           GLib.BindingFlags.SYNC_CREATE,
                                           this.command_valid_transform_to_string,
                                           null));
            this.bindings.append (
                this.action.bind_property ("states",
                                           this.pomodoro_state_togglebutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.pomodoro_state_transform_to_boolean,
                                           this.pomodoro_state_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("states",
                                           this.short_break_state_togglebutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.short_break_state_transform_to_boolean,
                                           this.short_break_state_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("states",
                                           this.long_break_state_togglebutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.long_break_state_transform_to_boolean,
                                           this.long_break_state_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("triggers",
                                           this.start_trigger_checkbutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.start_trigger_transform_to_boolean,
                                           this.start_trigger_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("triggers",
                                           this.complete_trigger_checkbutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.complete_trigger_transform_to_boolean,
                                           this.complete_trigger_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("triggers",
                                           this.skip_trigger_checkbutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.skip_trigger_transform_to_boolean,
                                           this.skip_trigger_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("triggers",
                                           this.pause_trigger_checkbutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.pause_trigger_transform_to_boolean,
                                           this.pause_trigger_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("triggers",
                                           this.resume_trigger_checkbutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.resume_trigger_transform_to_boolean,
                                           this.resume_trigger_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("triggers",
                                           this.enable_trigger_checkbutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.enable_trigger_transform_to_boolean,
                                           this.enable_trigger_transform_from_boolean));
            this.bindings.append (
                this.action.bind_property ("triggers",
                                           this.disable_trigger_checkbutton,
                                           "active",
                                           GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL,
                                           this.disable_trigger_transform_to_boolean,
                                           this.disable_trigger_transform_from_boolean));
        }

        private bool command_valid_transform_to_string (GLib.Binding   binding,
                                                        GLib.Value     source_value,
                                                        ref GLib.Value target_value)
        {
            target_value.set_string (
                source_value.get_boolean () ? null : "dialog-error-symbolic");

            return true;
        }

        private bool pomodoro_state_transform_to_boolean (GLib.Binding   binding,
                                                          GLib.Value     source_value,
                                                          ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.State.POMODORO) != 0);

            return true;
        }

        private bool pomodoro_state_transform_from_boolean (GLib.Binding   binding,
                                                            GLib.Value     source_value,
                                                            ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.states | Actions.State.POMODORO
                    : this.action.states & ~Actions.State.POMODORO);

            return true;
        }

        private bool short_break_state_transform_to_boolean (GLib.Binding   binding,
                                                             GLib.Value     source_value,
                                                             ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.State.SHORT_BREAK) != 0);

            return true;
        }

        private bool short_break_state_transform_from_boolean (GLib.Binding   binding,
                                                               GLib.Value     source_value,
                                                               ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.states | Actions.State.SHORT_BREAK
                    : this.action.states & ~Actions.State.SHORT_BREAK);

            return true;
        }

        private bool long_break_state_transform_to_boolean (GLib.Binding   binding,
                                                            GLib.Value     source_value,
                                                            ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.State.LONG_BREAK) != 0);

            return true;
        }

        private bool long_break_state_transform_from_boolean (GLib.Binding   binding,
                                                              GLib.Value     source_value,
                                                              ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.states | Actions.State.LONG_BREAK
                    : this.action.states & ~Actions.State.LONG_BREAK);

            return true;
        }

        private bool start_trigger_transform_to_boolean (GLib.Binding   binding,
                                                         GLib.Value     source_value,
                                                         ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.Trigger.START) != 0);

            return true;
        }

        private bool start_trigger_transform_from_boolean (GLib.Binding   binding,
                                                           GLib.Value     source_value,
                                                           ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.triggers | Actions.Trigger.START
                    : this.action.triggers & ~Actions.Trigger.START);

            return true;
        }

        private bool complete_trigger_transform_to_boolean (GLib.Binding   binding,
                                                            GLib.Value     source_value,
                                                            ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.Trigger.COMPLETE) != 0);

            return true;
        }

        private bool complete_trigger_transform_from_boolean (GLib.Binding   binding,
                                                              GLib.Value     source_value,
                                                              ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.triggers | Actions.Trigger.COMPLETE
                    : this.action.triggers & ~Actions.Trigger.COMPLETE);

            return true;
        }

        private bool skip_trigger_transform_to_boolean (GLib.Binding   binding,
                                                        GLib.Value     source_value,
                                                        ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.Trigger.SKIP) != 0);

            return true;
        }

        private bool skip_trigger_transform_from_boolean (GLib.Binding   binding,
                                                          GLib.Value     source_value,
                                                          ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.triggers | Actions.Trigger.SKIP
                    : this.action.triggers & ~Actions.Trigger.SKIP);

            return true;
        }

        private bool pause_trigger_transform_to_boolean (GLib.Binding   binding,
                                                         GLib.Value     source_value,
                                                         ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.Trigger.PAUSE) != 0);

            return true;
        }

        private bool pause_trigger_transform_from_boolean (GLib.Binding   binding,
                                                           GLib.Value     source_value,
                                                           ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.triggers | Actions.Trigger.PAUSE
                    : this.action.triggers & ~Actions.Trigger.PAUSE);

            return true;
        }

        private bool resume_trigger_transform_to_boolean (GLib.Binding   binding,
                                                          GLib.Value     source_value,
                                                          ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.Trigger.RESUME) != 0);

            return true;
        }

        private bool resume_trigger_transform_from_boolean (GLib.Binding   binding,
                                                            GLib.Value     source_value,
                                                            ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.triggers | Actions.Trigger.RESUME
                    : this.action.triggers & ~Actions.Trigger.RESUME);

            return true;
        }

        private bool enable_trigger_transform_to_boolean (GLib.Binding   binding,
                                                          GLib.Value     source_value,
                                                          ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.Trigger.ENABLE) != 0);

            return true;
        }

        private bool enable_trigger_transform_from_boolean (GLib.Binding   binding,
                                                            GLib.Value     source_value,
                                                            ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.triggers | Actions.Trigger.ENABLE
                    : this.action.triggers & ~Actions.Trigger.ENABLE);

            return true;
        }

        private bool disable_trigger_transform_to_boolean (GLib.Binding   binding,
                                                           GLib.Value     source_value,
                                                           ref GLib.Value target_value)
        {
            target_value.set_boolean (
                (source_value.get_flags () & Actions.Trigger.DISABLE) != 0);

            return true;
        }

        private bool disable_trigger_transform_from_boolean (GLib.Binding   binding,
                                                             GLib.Value     source_value,
                                                             ref GLib.Value target_value)
        {
            target_value.set_flags (source_value.get_boolean ()
                    ? this.action.triggers | Actions.Trigger.DISABLE
                    : this.action.triggers & ~Actions.Trigger.DISABLE);

            return true;
        }

        private void activate_add_variable (GLib.SimpleAction action,
                                            GLib.Variant?     parameter)
        {
            this.command_entry.insert_at_cursor (parameter.get_string ());
        }
    }
}
