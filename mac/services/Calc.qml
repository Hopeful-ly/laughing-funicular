pragma Singleton
import QtQuick
import Quickshell

// Small, safe arithmetic evaluator for the launcher (no eval()).
// Supports + - * / % ^ **, !, parentheses, implicit multiplication (2pi, 3(4+1)),
// hex/bin/oct literals, constants and common functions.
Singleton {
    id: root

    readonly property var consts: ({ pi: Math.PI, "π": Math.PI, e: Math.E, tau: 2 * Math.PI, phi: (1 + Math.sqrt(5)) / 2 })
    readonly property var fns: ({
        sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, floor: Math.floor, ceil: Math.ceil, round: Math.round,
        sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
        sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh, exp: Math.exp,
        ln: Math.log, log: Math.log10, log10: Math.log10, log2: Math.log2,
        min: Math.min, max: Math.max, pow: Math.pow, hypot: Math.hypot,
        deg: x => x * 180 / Math.PI, rad: x => x * Math.PI / 180
    })

    function tokenize(s) {
        const out = [];
        let i = 0;
        while (i < s.length) {
            const c = s[i];
            if (/\s/.test(c) || c === "_") { i++; continue; }
            let m = s.slice(i).match(/^(0x[0-9a-f]+|0b[01]+|0o[0-7]+|(\d+(\.\d*)?|\.\d+)(e[+-]?\d+)?)/i);
            if (m) {
                const t = m[0].toLowerCase();
                const v = t.startsWith("0x") ? parseInt(t.slice(2), 16) : t.startsWith("0b") ? parseInt(t.slice(2), 2) : t.startsWith("0o") ? parseInt(t.slice(2), 8) : parseFloat(t);
                out.push({ t: "num", v: v }); i += m[0].length; continue;
            }
            m = s.slice(i).match(/^([a-zA-Zπ][a-zA-Z0-9]*)/);
            if (m) { out.push({ t: "id", v: m[0].toLowerCase() }); i += m[0].length; continue; }
            if (s.startsWith("**", i)) { out.push({ t: "op", v: "^" }); i += 2; continue; }
            if ("+-*/%^!(),×÷−".indexOf(c) >= 0) {
                const map = { "×": "*", "÷": "/", "−": "-" };
                out.push({ t: "op", v: map[c] || c }); i++; continue;
            }
            throw "bad char";
        }
        return out;
    }

    // Recursive descent: expr := term (('+'|'-') term)*
    function evaluate(input) {
        const toks = tokenize(input);
        let p = 0;
        const peek = () => toks[p];
        const eat = (v) => { if (toks[p] && toks[p].v === v) { p++; return true; } return false; };
        const startsPrimary = (t) => t && (t.t === "num" || t.t === "id" || t.v === "(");

        function expr() {
            let v = term();
            while (peek() && (peek().v === "+" || peek().v === "-")) {
                const op = toks[p++].v; const r = term();
                v = op === "+" ? v + r : v - r;
            }
            return v;
        }
        function term() {
            let v = unary();
            for (;;) {
                const t = peek();
                if (t && (t.v === "*" || t.v === "/" || t.v === "%")) {
                    p++; const r = unary();
                    v = t.v === "*" ? v * r : t.v === "/" ? v / r : v % r;
                } else if (startsPrimary(t)) {
                    v = v * unary();          // implicit multiplication
                } else break;
            }
            return v;
        }
        function unary() {
            if (eat("-")) return -unary();
            if (eat("+")) return unary();
            return power();
        }
        function power() {
            const b = postfix();
            if (eat("^")) return Math.pow(b, unary());
            return b;
        }
        function fact(n) {
            if (n < 0 || n !== Math.floor(n) || n > 170) throw "bad factorial";
            let r = 1; for (let i = 2; i <= n; i++) r *= i; return r;
        }
        function postfix() {
            let v = primary();
            while (eat("!")) v = fact(v);
            return v;
        }
        function primary() {
            const t = toks[p++];
            if (!t) throw "eof";
            if (t.t === "num") return t.v;
            if (t.v === "(") { const v = expr(); eat(")"); return v; }
            if (t.t === "id") {
                if (root.fns[t.v] !== undefined && peek() && peek().v === "(") {
                    p++;
                    const args = [];
                    if (!eat(")")) {
                        do { args.push(expr()); } while (eat(","));
                        if (!eat(")")) throw "missing )";
                    }
                    return root.fns[t.v].apply(null, args);
                }
                if (root.fns[t.v] !== undefined && startsPrimary(peek())) return root.fns[t.v](postfix());
                if (root.consts[t.v] !== undefined) return root.consts[t.v];
            }
            throw "unexpected";
        }
        const v = expr();
        if (p < toks.length) throw "trailing";
        return v;
    }

    // Returns { ok, value, text } — only "ok" when the input looks like maths.
    function tryEval(input) {
        const s = input.trim().replace(/^=/, "");
        if (s.length === 0) return { ok: false };
        if (!/[\d)πe]/i.test(s)) return { ok: false };
        const looksMath = /[+\-*/%^!×÷()]/.test(s) || /^[a-z]+\s*\(/i.test(s) || /^0[xbo]/i.test(s) || input.trim().startsWith("=");
        if (!looksMath) return { ok: false };
        try {
            const v = evaluate(s);
            if (typeof v !== "number" || !isFinite(v)) return { ok: false };
            return { ok: true, value: v, text: format(v) };
        } catch (e) { return { ok: false }; }
    }

    function format(v) {
        if (Number.isInteger(v) && Math.abs(v) < 1e16) return v.toLocaleString(Qt.locale("en_US"), "f", 0);
        const a = Math.abs(v);
        if (a !== 0 && (a < 1e-6 || a >= 1e16)) return v.toExponential(8).replace(/\.?0+e/, "e");
        return parseFloat(v.toPrecision(12)).toString();
    }
    function plain(v) { return Number.isInteger(v) ? String(v) : parseFloat(v.toPrecision(12)).toString(); }
}
