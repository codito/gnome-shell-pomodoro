/*
 * based on keyboard-shortcuts.c from gnome-control-center
 *
 * Copyright (c) 2013 gnome-pomodoro contributors
 *               2010 Intel, Inc
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
 *          Thomas Wood <thomas.wood@intel.com>
 *          Rodrigo Moya <rodrigo@gnome.org>
 */

/* TODO:
 * Handle integration with window manager
 *  - suppress any keybings from being triggered
 *  - if keybinding is taken, notify about it
 *
 * For now gnome-shell extension is responsible for setting it.
 */

using GLib;


namespace Pomodoro
{
    private errordomain AcceleratorError
    {
        INVALID,
        FORBIDDEN,
        TYPING_COLLISION
    }

    private class Accelerator : GLib.Object
    {
        private uint key { get; private set; }
        private Gdk.ModifierType modifiers { get; private set; }

        public string name {
            owned get {
                var name = new GLib.StringBuilder ();

                foreach (var element in this.get_keys_internal (true)) {
                    name.append (element);
                }

                return name.str;
            }
            set {
                uint keyval = 0;
                Gdk.ModifierType modifiers = 0;

                Pomodoro.Accelerator.parse (value, out keyval, out modifiers);

                this.set_keyval (keyval, modifiers);
            }
        }

        public string display_name {
            owned get {
                var name = new GLib.StringBuilder ();
                var is_first = true;

                foreach (var element in this.get_keys_internal (false))
                {
                    if (is_first) {
                        is_first = false;
                    } else {
                        name.append (" + ");
                    }

                    name.append (element);
                }

                return name.str;
            }
        }

        public Accelerator.from_name (string name)
        {
            this.name = name;
        }

        private static void parse (string?              name,
                                   out uint             keyval,
                                   out Gdk.ModifierType modifiers)
        {
            int pos = 0;
            int start = 0;
            char chr = '\0';
            bool is_modifier = false;

            keyval = 0;
            modifiers = 0;

            if (name == null || name == "") {
                return;
            }

            while ((chr = name[pos]) != '\0')
            {
                if (chr == '<') {
                    start = pos + 1;
                    is_modifier = true;
                }
                else if (chr == '>' && is_modifier)
                {
                    var modifier = name.slice (start, pos);

                    if (modifier == "Ctrl" || modifier == "Control") {
                        modifiers |= Gdk.ModifierType.CONTROL_MASK;
                    }

                    if (modifier == "Alt") {
                        modifiers |= Gdk.ModifierType.ALT_MASK;
                    }

                    if (modifier == "Shift") {
                        modifiers |= Gdk.ModifierType.SHIFT_MASK;
                    }

                    if (modifier == "Super") {
                        modifiers |= Gdk.ModifierType.SUPER_MASK;
                    }

                    is_modifier = false;
                    start = pos + 1;
                }

                pos++;
            }

            keyval = Gdk.keyval_from_name (name.slice (start, pos));
        }

        public void unset ()
        {
            this.key = 0;
            this.modifiers = 0;

            this.changed ();
        }

        private static void normalize (ref uint             keyval,
                                       ref Gdk.ModifierType modifiers)
        {
            Gdk.ModifierType keyval_modifier = 0;

            switch (keyval)
            {
                case Gdk.Key.Control_L:
                case Gdk.Key.Control_R:
                    keyval_modifier = Gdk.ModifierType.CONTROL_MASK;
                    break;

                case Gdk.Key.Shift_L:
                case Gdk.Key.Shift_R:
                    keyval_modifier = Gdk.ModifierType.SHIFT_MASK;
                    break;

                case Gdk.Key.Super_L:
                case Gdk.Key.Super_R:
                    keyval_modifier = Gdk.ModifierType.SUPER_MASK;
                    break;

                case Gdk.Key.Alt_L:
                case Gdk.Key.Alt_R:
                    keyval_modifier = Gdk.ModifierType.ALT_MASK;
                    break;
            }

            if (keyval_modifier != 0) {
                keyval = 0;
                modifiers |= keyval_modifier;
            }

            modifiers &= (Gdk.ModifierType.CONTROL_MASK |
                          Gdk.ModifierType.SHIFT_MASK |
                          Gdk.ModifierType.SUPER_MASK |
                          Gdk.ModifierType.ALT_MASK);
        }

        public void set_keyval (uint             keyval,
                                Gdk.ModifierType modifiers)
        {
            Accelerator.normalize (ref keyval,
                                   ref modifiers);

            if (this.key != keyval || this.modifiers != modifiers)
            {
                this.key = keyval;
                this.modifiers = modifiers;

                this.changed ();
            }
        }

        public void validate () throws AcceleratorError
        {
            var key = this.key;
            var modifiers = this.modifiers;

            if (key == 0 && modifiers == 0)
            {
                return;
            }

            if (!Gtk.accelerator_valid (key, modifiers))
            {
                throw new AcceleratorError.INVALID ("Invalid");
            }

            if (key != 0 && modifiers == 0)
            {
                if (key == Gdk.Key.Escape ||
                    key == Gdk.Key.BackSpace ||
                    key == Gdk.Key.Return)
                {
                    throw new AcceleratorError.FORBIDDEN ("Forbidden");
                }
            }

            /* Check for unmodified keys */
            if (key != 0 && (modifiers == 0 || modifiers == Gdk.ModifierType.SHIFT_MASK))
            {
                if ((key >= Gdk.Key.a && key <= Gdk.Key.z) ||
                    (key >= Gdk.Key.A && key <= Gdk.Key.Z) ||
                    (key >= Gdk.Key.@0 && key <= Gdk.Key.@9) ||
                    (key >= Gdk.Key.kana_fullstop && key <= Gdk.Key.semivoicedsound) ||
                    (key >= Gdk.Key.Arabic_comma && key <= Gdk.Key.Arabic_sukun) ||
                    (key >= Gdk.Key.Serbian_dje && key <= Gdk.Key.Cyrillic_HARDSIGN) ||
                    (key >= Gdk.Key.Greek_ALPHAaccent && key <= Gdk.Key.Greek_omega) ||
                    (key >= Gdk.Key.hebrew_doublelowline && key <= Gdk.Key.hebrew_taf) ||
                    (key >= Gdk.Key.Thai_kokai && key <= Gdk.Key.Thai_lekkao) ||
                    (key >= Gdk.Key.Hangul && key <= Gdk.Key.Hangul_Special) ||
                    (key >= Gdk.Key.Hangul_Kiyeog && key <= Gdk.Key.Hangul_J_YeorinHieuh))
                {
                    throw new AcceleratorError.TYPING_COLLISION ("Typing collision");
                }
            }
        }

        private string[] get_keys_internal (bool escape)
        {
            var elements = new string[0];

            if (Gdk.ModifierType.SHIFT_MASK in this.modifiers) {
                elements += escape ? "<Shift>" : "Shift";
            }

            if (Gdk.ModifierType.SUPER_MASK in this.modifiers) {
                elements += (escape ? "<Super>" : "Super");
            }

            if (Gdk.ModifierType.CONTROL_MASK in this.modifiers) {
                elements += (escape ? "<Ctrl>" : "Ctrl");
            }

            if (Gdk.ModifierType.ALT_MASK in this.modifiers) {
                elements += (escape ? "<Alt>" : "Alt");
            }

            if (this.key != 0) {
                var keyval = Gdk.keyval_to_upper (this.key);
                var name = Gdk.keyval_name (keyval);

                if (escape) {
                    elements += (name);
                }
                else {
                    unichar key = Gdk.keyval_to_unicode (keyval);

                    elements += (key > 0 ? key.to_string () : name.replace ("_", " "));
                }
            }

            return elements;
        }

        public string[] get_keys ()
        {
            return this.get_keys_internal (false);
        }

        public virtual signal void changed ()
        {
            this.notify_property ("name");
            this.notify_property ("display-name");
        }
    }
}
