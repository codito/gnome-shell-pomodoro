using GLib;


namespace Pomodoro
{
    public errordomain ExpressionParserError
    {
        SYNTAX_ERROR,
        UNKNOWN_IDENTIFIER,
    }


    private enum TokenType
    {
        INVALID,
        STRING_LITERAL,
        NUMERIC_LITERAL,
        IDENTIFIER,
        OPERATOR,
        PARENTHESIS,
    }


    [Compact]
    private class Token
    {
        public TokenType   type;
        public int         span_start;
        public int         span_end;
        public string      text;
        public weak Token? prev;
        public weak Token? next;
        public weak Token? parent;
        public weak Token? children;  // first child
        public uint        precedence = 0U;
        public weak Token? matching_token;

        public uint n_children ()
        {
            unowned var child = this.children;
            var n_children = 0U;

            while (child != null)
            {
                child = child.next;
                n_children++;
            }

            return n_children;
        }

        public unowned Token get_root ()
        {
            unowned var root = this;

            while (root.parent != null) {
                root = root.parent;
            }

            return root;
        }

        public unowned Token? last_sibling ()
        {
            unowned var last_sibling = this.next;

            while (last_sibling.next != null) {
                last_sibling = last_sibling.next;
            }

            return last_sibling;
        }

        public unowned Token? last_child ()
        {
            unowned var last_child = this.children;

            while (last_child.next != null) {
                last_child = last_child.next;
            }

            return last_child;
        }

        public void append (Token token)
                            requires (token.parent == null)
        {
            unowned var last_token = this;

            while (last_token.next != null) {
                last_token = last_token.next;
            }

            last_token.next = token;
            token.prev = last_token;
            token.parent = this.parent;
        }

        public inline void append_child (Token token)
                                         requires (token.parent == null)
        {
            if (this.children == null)
            {
                token.parent = this;
                this.children = token;
            }
            else {
                this.children.append (token);
            }
        }

        /**
         * Insert given token as a new parent.
         */
        public void insert_parent (Token token)
                                   requires (token.parent == null && token.children == null)
                                   requires (token.prev == null && token.next == null)
        {
            if (this.parent != null && this.parent.children == this) {
                this.parent.children = token;
            }

            if (this.prev != null) {
                this.prev.next = token;
            }

            token.parent   = this.parent;
            token.prev     = this.prev;
            token.children = this;

            this.parent    = token;
            this.prev      = null;
        }

        public void foreach_child (GLib.Func<Token> func)
        {
            unowned var child = this.children;

            while (child != null)
            {
                func (child);
                child = child.next;
            }
        }
    }


    [Compact]
    internal class ExpressionParser
    {
        private const uint BASE_OPERATOR_PRECEDENCE = 1000U;

        public GLib.HashTable<string, Pomodoro.Operator> operators;

        public ExpressionParser ()
        {
            this.operators = new GLib.HashTable<string, Pomodoro.Operator> (
                GLib.str_hash, GLib.str_equal);

            Pomodoro.Operator.@foreach (
                (operator) => {
                    operators.insert (operator.to_string (), operator);
                });
        }

        private static string format_error_context (string text,
                                                    int    index,
                                                    uint   limit = 10)
        {
            int span_start = index;
            int span_end = index;
            int n = 0;
            unichar chr;

            while (n < limit && text.get_next_char (ref span_end, out chr))
            {
                n++;
            }

            return "'%s...' at position %d".printf (
                text.substring (span_start, span_end - span_start),
                span_start);
        }

        private Token tokenize_string_literal (string  text,
                                               ref int index)
                                               throws Pomodoro.ExpressionParserError
        {
            var token = new Token () {
                type = TokenType.STRING_LITERAL,
                span_start = index,
            };
            var is_escaped = false;
            var string_builder = new GLib.StringBuilder ();
            unichar chr;

            index++;  // skip first quote

            while (text.get_next_char (ref index, out chr))
            {
                if (chr == '\\') {
                    is_escaped = !is_escaped;
                    continue;
                }

                if (is_escaped)
                {
                    switch (chr)
                    {
                        case 'n':
                            string_builder.append ("\n");
                            break;

                        case 'r':
                            string_builder.append ("\r");
                            break;

                        case 't':
                            string_builder.append ("\t");
                            break;

                        case 'f':
                            string_builder.append ("\f");
                            break;

                        case 'b':
                            string_builder.append ("\b");
                            break;

                        default:
                            string_builder.append_unichar (chr);
                            break;
                    }

                    is_escaped = false;

                    continue;
                }

                if (chr == '"')
                {
                    token.span_end = index;
                    token.text = string_builder.str.dup ();  // TODO: is dup() necessary?

                    return token;
                }

                string_builder.append_unichar (chr);
            }

            throw new Pomodoro.ExpressionParserError.SYNTAX_ERROR ("Unquoted string at %d", index);
        }

        private Token tokenize_identifier (string  text,
                                           ref int index)
        {
            var token = new Token () {
                type = TokenType.IDENTIFIER,
                span_start = index,
                span_end = index + 1,
            };
            unichar chr;

            index++;  // skip first char

            while (text.get_next_char (ref index, out chr))
            {
                if ((chr >= 'a' && chr <= 'z') ||
                    (chr >= 'A' && chr <= 'Z') ||
                    (chr >= '0' && chr <= '9'))
                {
                    token.span_end = index;
                    continue;
                }
                else {
                    index = token.span_end;
                    break;
                }
            }

            token.text = text.substring ((long) token.span_start,
                                         (long) (token.span_end - token.span_start));

            return token;
        }

        private Token tokenize_operator (string  text,
                                         ref int index)
                                         throws Pomodoro.ExpressionParserError
        {
            var token = new Token () {
                type = TokenType.OPERATOR,
                span_start = index,
                span_end = index + 1,
            };
            unichar chr;

            index++;  // skip first character

            while (text.get_next_char (ref index, out chr))
            {
                if (chr == '|' ||
                    chr == '&' ||
                    chr == '=' ||
                    chr == '!' ||
                    chr == '>' ||
                    chr == '<')
                {
                    token.span_end = index;
                }
                else {
                    index = token.span_end;
                    break;
                }
            }

            token.text = text.substring (token.span_start, token.span_end - token.span_start);

            if (!this.operators.contains (token.text)) {
                throw new Pomodoro.ExpressionParserError.SYNTAX_ERROR (
                    "Invalid operator '%s' at position %d", token.text, index);
            }

            return token;
        }

        private Token? tokenize_numeric_literal (string  text,
                                                 ref int index)
        {
            var token = new Token () {
                type = TokenType.NUMERIC_LITERAL,
                span_start = index,
                span_end = index + 1,
            };
            unichar chr;

            index++;  // skip first char

            while (text.get_next_char (ref index, out chr))
            {
                if (chr >= '0' && chr <= '9')
                {
                    token.span_end = index;
                    continue;
                }
                else {
                    index = token.span_end;
                    break;
                }
            }

            token.text = text.substring ((long) token.span_start,
                                         (long) (token.span_end - token.span_start));

            return token;
        }

        private GLib.Array<Token> tokenize (string text)
                                            throws Pomodoro.ExpressionParserError
        {
            var tokens = new GLib.Array<Token>.sized (false, true, 8U);

            unichar chr;
            int     chr_span_start = 0;
            int     chr_span_end = 0;

            while (text.get_next_char (ref chr_span_end, out chr))
            {
                switch (chr)
                {
                    case ' ':
                        break;

                    case '(':
                    case ')':
                        tokens.append_val (
                            new Token () {
                                type       = TokenType.PARENTHESIS,
                                span_start = chr_span_start,
                                span_end   = chr_span_end,
                                text       = chr.to_string (),
                            });
                        break;

                    case '"':
                        chr_span_end = chr_span_start;
                        tokens.append_val (this.tokenize_string_literal (text, ref chr_span_end));
                        break;

                    case '|':
                    case '&':
                    case '=':
                    case '!':
                    case '>':
                    case '<':
                        chr_span_end = chr_span_start;
                        tokens.append_val (this.tokenize_operator (text, ref chr_span_end));
                        break;

                    default:
                        if ((chr >= 'a' && chr <= 'z') ||
                            (chr >= 'A' && chr <= 'Z'))
                        {
                            chr_span_end = chr_span_start;
                            tokens.append_val (this.tokenize_identifier (text, ref chr_span_end));

                            break;
                        }

                        if ((chr >= '0' && chr <= '9') || chr == '-') {
                            chr_span_end = chr_span_start;
                            tokens.append_val (
                                this.tokenize_numeric_literal (text, ref chr_span_end));

                            break;
                        }

                        if (chr.isspace ()) {
                            break;
                        }

                        throw new Pomodoro.ExpressionParserError.SYNTAX_ERROR (
                            "Unexpected expression %s",
                            format_error_context (text, chr_span_start));
                }

                chr_span_start = chr_span_end;
            }

            return tokens;
        }

        private inline unowned Token? find_open_parenthesis (Token? token)
        {
            unowned var node = token;

            while (node != null)
            {
                if (node.type == Pomodoro.TokenType.PARENTHESIS && node.matching_token == null) {
                    return node;
                }

                node = node.parent;
            }

            return null;
        }

        /**
         * Validate roughly if syntax makes sense.
         */
        private inline bool is_valid_token (Token  token,
                                            Token? previous_token)
        {
            if (previous_token == null) {
                return token.type != TokenType.OPERATOR;
            }

            switch (previous_token.type)
            {
                case TokenType.OPERATOR:
                    return token.type != TokenType.OPERATOR;

                case TokenType.PARENTHESIS:
                    return true;  // the type of parenthesis is validated later

                case TokenType.STRING_LITERAL:
                case TokenType.NUMERIC_LITERAL:
                case TokenType.IDENTIFIER:
                    return token.type == OPERATOR ||
                           token.type == PARENTHESIS;

                default:
                    assert_not_reached ();
            }
        }

        private inline bool is_valid_expression (Token? last_token)
        {
            if (last_token == null) {
                return true;
            }

            if (last_token.type == TokenType.OPERATOR) {
                return false;
            }

            if (this.find_open_parenthesis (last_token) != null) {
                return false;
            }

            return true;
        }

        private inline uint determine_precedence (Token  token,
                                                  Token? previous_token)
        {
            switch (token.type)
            {
                case TokenType.OPERATOR:
                    var operator = this.operators.lookup (token.text);

                    return BASE_OPERATOR_PRECEDENCE + operator.get_precedence ();

                case TokenType.PARENTHESIS:
                    // We only keep the starting token in the final tree. The closing parenthesis
                    // is kept as `token.matching_token` to indicate whether parenthesis is still
                    // open while building the token tree.
                    return previous_token != null &&
                           previous_token.type == Pomodoro.TokenType.PARENTHESIS
                        ? previous_token.precedence - 1U
                        : BASE_OPERATOR_PRECEDENCE;

                default:
                    return 0U;
            }
        }

        private inline unowned Token? link_tokens (Token  token,
                                                   Token? previous_token)
        {
            if (token.type == Pomodoro.TokenType.OPERATOR)
            {
                // If the same operator is repeated, ignore it and use the first token.
                // Find closest operator.
                unowned var reference_token = previous_token;

                while (reference_token.parent != null &&
                       reference_token.type != Pomodoro.TokenType.OPERATOR)
                {
                    reference_token = reference_token.parent;
                }

                if (reference_token.type == Pomodoro.TokenType.OPERATOR &&
                    reference_token.text == token.text)
                {
                    return reference_token;  // use first operator token for an operation
                }
            }

            if (previous_token != null)
            {
                // Find closest ancestor with higher precedence.
                unowned var reference_token = previous_token;

                if (token.precedence > 0 &&
                    reference_token.parent != null &&
                    reference_token.parent.precedence > token.precedence)  // TODO: we only look at direct parent, use a loop to find `reference_token`?
                {
                    reference_token = reference_token.parent;
                    reference_token.insert_parent (token);

                    assert (token.precedence < reference_token.precedence);
                }
                else if (token.precedence > reference_token.precedence)
                {
                    reference_token.insert_parent (token);
                }
                else if (token.precedence < reference_token.precedence)
                {
                    reference_token.append_child (token);
                }
                else {
                    reference_token.append (token);
                }
            }

            return token;
        }

        /**
         * Convert array of tokens into an Abstract Syntax Tree (AST).
         *
         * The AST represents the hierarchical structure of the expression. For example
         * `A || B && C` we want to build a tree:
         *
         *       ||
         *      /  \
         *     A   &&
         *         /  \
         *        B    C
         */
        public unowned Token? build_token_tree (GLib.Array<Token> tokens)
                                                throws Pomodoro.ExpressionParserError
        {
            unowned Token? token = null;
            unowned Token? previous_token = null;

            for (var index = 0U; index < tokens.length; index++)
            {
                token = tokens.index (index);

                // Validate token
                if (!this.is_valid_token (token, previous_token)) {
                    throw new Pomodoro.ExpressionParserError.SYNTAX_ERROR (
                        "Unexpected token '%s' at position %d", token.text, token.span_start);
                }

                if (token.type == TokenType.PARENTHESIS && token.text == ")")
                {
                    unowned var reference_token = this.find_open_parenthesis (previous_token);

                    if (reference_token == null) {
                        throw new Pomodoro.ExpressionParserError.SYNTAX_ERROR (
                            "Unmatched parenthesis");
                    }

                    reference_token.matching_token = token;
                    previous_token = token = reference_token;
                    continue;
                }

                // Determine precedence and associativity
                token.precedence = this.determine_precedence (token, previous_token);

                // Link tokens and form a tree
                token = this.link_tokens (token, previous_token);

                previous_token = token;
            }

            if (!this.is_valid_expression (token)) {
                throw new Pomodoro.ExpressionParserError.SYNTAX_ERROR (
                    "Unexpected end of expression");
            }

            return token?.get_root ();
        }

        /**
         * We serialize timestamps and enums to `string`, for the result expression to
         * look more like JSON. But this has cost - we now have to deduce original types from
         * the strings during parsing.
         */
        private inline Pomodoro.Value cast_string_literal (string text)
        {
            switch (text)
            {
                case "undefined":
                    return new Pomodoro.StateValue (Pomodoro.State.UNDEFINED);

                case "pomodoro":
                    return new Pomodoro.StateValue (Pomodoro.State.POMODORO);

                case "break":
                    return new Pomodoro.StateValue (Pomodoro.State.BREAK);

                case "short-break":
                    return new Pomodoro.StateValue (Pomodoro.State.SHORT_BREAK);

                case "long-break":
                    return new Pomodoro.StateValue (Pomodoro.State.LONG_BREAK);

                case "scheduled":
                    return new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.SCHEDULED);

                case "in-progress":
                    return new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.IN_PROGRESS);

                case "completed":
                    return new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.COMPLETED);

                case "uncompleted":
                    return new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.UNCOMPLETED);

                default:
                    break;
            }

            var timestamp = Pomodoro.Timestamp.from_iso8601 (text);

            if (timestamp != Pomodoro.Timestamp.UNDEFINED) {
                return new Pomodoro.TimestampValue (timestamp);
            }

            return new Pomodoro.StringValue (text);
        }

        private inline Pomodoro.Value cast_numeric_literal (string text)
        {
            // XXX: handle overflow errors when parsing int?

            return new Pomodoro.IntervalValue (int64.parse (text));
        }

        private inline Pomodoro.Expression? interpret_identifier (Token token)
                                                                  throws Pomodoro.ExpressionParserError
        {
            assert (token.n_children () == 0);

            if (token.text == "true") {
                return new Pomodoro.Constant (new Pomodoro.BooleanValue (true));
            }

            if (token.text == "false") {
                return new Pomodoro.Constant (new Pomodoro.BooleanValue (false));
            }

            var name = Pomodoro.from_camel_case (token.text);

            if (Pomodoro.find_variable (name) == null) {
                throw new Pomodoro.ExpressionParserError.UNKNOWN_IDENTIFIER (
                    "Unknown identifier '%s' at %d", token.text, token.span_start);
            }

            return new Pomodoro.Variable (name);
        }

        private inline Pomodoro.Expression? interpret_operator (Token token)
                                                            throws Pomodoro.ExpressionParserError
        {
            var operator = this.operators.lookup (token.text);
            var n_children = token.n_children ();
            unowned var child = token.children;

            switch (operator.get_category ())
            {
                case Pomodoro.OperatorCategory.LOGICAL:
                    assert (n_children >= 2);

                    var arguments = new Pomodoro.Expression[n_children];

                    for (var index = 0; index < n_children; index++) {
                        arguments[index] = this.interpret (child);
                        child = child.next;
                    }

                    return new Pomodoro.Operation.with_argv (operator, arguments);

                case Pomodoro.OperatorCategory.COMPARISON:
                    assert (n_children == 2);

                    var argument_lhs = this.interpret (child);
                    var argument_rhs = this.interpret (child.next);

                    return new Pomodoro.Comparison (argument_lhs, operator, argument_rhs);

                default:
                    assert_not_reached ();
            }
        }

        /**
         * Convert token tree (aka AST) into our expression.
         */
        private Pomodoro.Expression? interpret (Token? token)
                                                throws Pomodoro.ExpressionParserError
        {
            if (token == null) {
                return null;
            }

            switch (token.type)
            {
                case TokenType.STRING_LITERAL:
                    assert (token.n_children () == 0);

                    return new Pomodoro.Constant (this.cast_string_literal (token.text));

                case TokenType.NUMERIC_LITERAL:
                    assert (token.n_children () == 0);

                    return new Pomodoro.Constant (this.cast_numeric_literal (token.text));

                case TokenType.IDENTIFIER:
                    assert (token.n_children () == 0);

                    return this.interpret_identifier (token);

                case TokenType.OPERATOR:
                    return this.interpret_operator (token);

                case TokenType.PARENTHESIS:
                    return this.interpret (token.children);

                default:
                    GLib.error ("Unandled token: %s", token.type.to_string ());
                    assert_not_reached ();
            }
        }

        public Pomodoro.Expression? parse (string text)
                                           throws Pomodoro.ExpressionParserError
        {
            var tokens = this.tokenize (text);
            unowned var root = this.build_token_tree (tokens);

            return this.interpret (root);
        }
    }
}
