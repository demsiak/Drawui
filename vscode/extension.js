'use strict';
const vscode = require('vscode');
const api = require('./api.json');

const classes = api.classes;
const LANGS = ['lua', 'luau'];

function chain(name) {
    const out = [];
    for (let c = name; c && classes[c]; c = classes[c].base) out.unshift(c);
    return out;
}
function propsOf(name) {
    if (name === '*') return allProps;
    const out = {};
    for (const c of chain(name)) Object.assign(out, classes[c].props);
    const def = classes[name];
    if (def && def.text) Object.assign(out, api.textProps);
    if (def && def.image) Object.assign(out, api.imageProps);
    return out;
}
function isGui(name) { return name === '*' || chain(name).some(c => classes[c].gui); }
const creatable = Object.keys(classes).filter(n => !classes[n].abstract);
const allProps = {};
for (const n of Object.keys(classes)) Object.assign(allProps, classes[n].props);
Object.assign(allProps, api.textProps, api.imageProps);

function classOfProp(prop) {
    for (const n of creatable) if (propsOf(n)[prop]) return n;
}

// ---- Lightweight Luau scanner ------------------------------------------------------------
// Walks the text before the cursor, skipping strings and comments, and keeps a stack of open
// `{` tables. Each table remembers what it belongs to (New "Class" props, [Children], a sugar
// key like Stroke = { ... }), the keys already written and where the current entry starts.

const CTOR = /(?:\bNew|\.New|\bnew|\.new|\.Create)\s*\(?\s*["'](\w+)["']\s*\)?\s*,?\s*$/;

function ownerOf(text, i, stack) {
    const before = text.slice(Math.max(0, i - 300), i);
    let m = CTOR.exec(before);
    if (m) return { kind: 'props', cls: m[1] };
    if (/Hydrate\s*\(\s*[\w.:]+\s*\)\s*$/.test(before)) return { kind: 'props', cls: '*' };
    if (/\[\s*(?:[\w.]*\.)?Children\s*\]\s*=\s*$/.test(before)) return { kind: 'children' };
    const parent = stack[stack.length - 1];
    if (parent && parent.owner.kind === 'props' && (m = /([A-Za-z_]\w*)\s*=\s*$/.exec(before))) {
        const sugar = api.sugar[m[1]];
        if (sugar) return { kind: 'sugar', cls: sugar.class, sugar: m[1] };
    }
    return { kind: 'other' };
}

function scan(text) {
    const stack = [];
    let state = null;
    let i = 0;
    const n = text.length;
    while (i < n) {
        const ch = text[i];
        if (state) {
            if (state.type === 'line') {
                if (ch === '\n') state = null;
                i++;
            } else if (state.type === 'str') {
                if (ch === '\\') { i += 2; continue; }
                if (ch === state.quote || ch === '\n') state = null;
                i++;
            } else {
                const close = ']' + '='.repeat(state.level) + ']';
                if (text.startsWith(close, i)) { i += close.length; state = null; } else i++;
            }
            continue;
        }
        if (ch === '-' && text[i + 1] === '-') {
            const m = /^\[(=*)\[/.exec(text.slice(i + 2, i + 24));
            if (m) { state = { type: 'long', comment: true, level: m[1].length, start: i }; i += 2 + m[0].length; }
            else { state = { type: 'line', start: i }; i += 2; }
            continue;
        }
        if (ch === '"' || ch === "'" || ch === '`') { state = { type: 'str', quote: ch, start: i }; i++; continue; }
        if (ch === '[') {
            const m = /^\[(=*)\[/.exec(text.slice(i, i + 22));
            if (m) { state = { type: 'long', comment: false, level: m[1].length, start: i }; i += m[0].length; continue; }
        }
        if (ch === '{') {
            stack.push({ owner: ownerOf(text, i, stack), keys: new Set(), segStart: i + 1 });
        } else if (ch === '}') {
            stack.pop();
        } else if ((ch === ',' || ch === ';') && stack.length) {
            stack[stack.length - 1].segStart = i + 1;
        } else if (ch === '=') {
            if (text[i + 1] === '=') { i += 2; continue; }
            const top = stack[stack.length - 1];
            if (top && !'=<>~+-*/%^.'.includes(text[i - 1] || '')) {
                const m = /^\s*([A-Za-z_]\w*)\s*$/.exec(text.slice(top.segStart, i));
                if (m) top.keys.add(m[1]);
            }
        }
        i++;
    }
    return { stack, state };
}

function contextAt(document, position) {
    const offset = document.offsetAt(position);
    const text = document.getText().slice(Math.max(0, offset - 40000), offset);
    const { stack, state } = scan(text);
    return { text, stack, state, top: stack[stack.length - 1] };
}

// Names the library is bound to (UI by default, plus `local X = loadstring(...Drawui...)`).
function libNames(document) {
    const names = new Set(['UI', 'Drawui']);
    const re = /local\s+([A-Za-z_]\w*)\s*=\s*loadstring\([^\n]*Drawui/g;
    let m;
    const src = document.getText();
    while ((m = re.exec(src))) names.add(m[1]);
    return names;
}
function primaryLib(document) {
    return [...libNames(document)].find(n => n !== 'Drawui') || 'UI';
}
// Variables created from a known class: `local x = New "TextLabel"` / `x = UI.new("Frame"`.
function variableClasses(document) {
    const map = new Map();
    const re = /(?:local\s+)?([A-Za-z_]\w*)\s*=\s*(?:[\w.]*\.)?(?:New|new|Create)\s*\(?\s*["'](\w+)["']/g;
    let m;
    const src = document.getText();
    while ((m = re.exec(src))) map.set(m[1], m[2]);
    return map;
}

// ---- Completion items ---------------------------------------------------------------------
const K = vscode.CompletionItemKind;

function md(lines) { return new vscode.MarkdownString(lines.filter(Boolean).join('\n\n')); }
function propDoc(name, p, cls) {
    return md([
        '```luau\n' + name + ': ' + (p.enum ? p.enum + ' (' + api.enums[p.enum].map(v => '"' + v + '"').join(' | ') + ')' : p.type) + '\n```',
        p.doc,
        cls && cls !== '*' ? '*' + cls + '*' : null,
        p.readonly ? '_Read-only._' : null,
    ]);
}
function classDoc(name) {
    const def = classes[name];
    const props = Object.keys(propsOf(name)).filter(k => !propsOf(name)[k].readonly);
    return md(['**' + name + '**' + (def.base ? ' : ' + def.base : ''), def.doc, props.length ? 'Properties: ' + props.join(', ') : null]);
}

function item(label, kind, insert, detail, doc, sort) {
    const it = new vscode.CompletionItem(label, kind);
    if (insert !== undefined) it.insertText = typeof insert === 'string' ? new vscode.SnippetString(insert) : insert;
    if (detail) it.detail = detail;
    if (doc) it.documentation = doc;
    if (sort) it.sortText = sort;
    return it;
}

function classItems() {
    return creatable.map(n => item(n, K.Class, n, classes[n].modifier ? 'modifier' : 'class', classDoc(n), (classes[n].modifier ? '1' : '0') + n));
}
function eventItems(plain) {
    return Object.keys(api.events).map(e => {
        const args = (/^\(([^)]*)\)/.exec(api.events[e]) || [, ''])[1];
        const insert = plain ? e : e + ' = function(' + args + ')\n\t$0\nend';
        return item(e, K.Event, insert, 'event', md([api.events[e]]), '2' + e);
    });
}
function valueInsert(p) {
    if (p.type === 'boolean') return '${1|true,false|}';
    if (p.enum) return '"${1|' + api.enums[p.enum].join(',') + '|}"';
    return '${1:' + p.default.replace(/[$}\\]/g, '\\$&') + '}';
}
function propItems(cls, keys, withValues) {
    const props = propsOf(cls);
    return Object.keys(props).filter(k => !props[k].readonly && !keys.has(k)).map(k => {
        const p = props[k];
        const insert = withValues ? k + ' = ' + valueInsert(p) : k;
        return item(k, K.Property, insert, p.enum || p.type, propDoc(k, p, cls), '0' + k);
    });
}

function keyItems(document, owner, keys) {
    const lib = primaryLib(document);
    if (owner.kind === 'props') {
        const out = propItems(owner.cls, keys, true);
        if (isGui(owner.cls)) {
            for (const [name, s] of Object.entries(api.sugar)) {
                if (!keys.has(name)) out.push(item(name, K.Module, s.snippet, 'adds ' + s.class, md([s.doc]), '1' + name));
            }
            out.push(...eventItems(false).filter(it => !keys.has(it.label)));
            out.push(item('[' + lib + '.Children]', K.Field, '[' + lib + '.Children] = {\n\t$0\n}', 'child objects', md([api.members.Children.doc]), '3a'));
        }
        out.push(item('[' + lib + '.Ref]', K.Field, '[' + lib + '.Ref] = function(${1:obj})\n\t$0\nend', 'receives the object', md([api.members.Ref.doc]), '3b'));
        out.push(item('[' + lib + '.OnChange]', K.Field, '[' + lib + '.OnChange "${1:Text}"] = function(${2:value})\n\t$0\nend', 'property listener', md([api.members.OnChange.doc]), '3c'));
        if (!keys.has('Parent')) out.push(item('Parent', K.Property, 'Parent = ${1:parent}', 'object', md(['Parent object. Set last.']), '0Parent'));
        return out;
    }
    if (owner.kind === 'sugar') {
        const out = propItems(owner.cls, keys, true);
        if (owner.sugar === 'Padding') {
            for (const k of api.sugar.Padding.keys) if (!keys.has(k)) out.push(item(k, K.Property, k + ' = ${1:8}', 'number | UDim', null, '0' + k));
        }
        return out;
    }
    if (owner.kind === 'children') {
        return creatable.map(n => {
            const it = item('New "' + n + '"', K.Class, 'New "' + n + '" {\n\t$0\n},', classes[n].modifier ? 'modifier' : 'class', classDoc(n), (classes[n].modifier ? '1' : '0') + n);
            it.filterText = n;
            return it;
        });
    }
    return [];
}

function valueItems(owner, key) {
    let cls = owner.kind === 'props' || owner.kind === 'sugar' ? owner.cls : '*';
    const p = propsOf(cls)[key] || allProps[key];
    if (p) {
        if (p.enum) return api.enums[p.enum].map((v, i) => item('"' + v + '"', K.EnumMember, '"' + v + '"', p.enum, null, String(i)));
        if (p.type === 'boolean') return ['true', 'false'].map(v => item(v, K.Value, v));
        return [item(p.default, K.Value, valueInsert(p), p.type)];
    }
    if (api.sugar[key]) return [item(api.sugar[key].snippet.replace(/^\w+ = /, ''), K.Snippet, api.sugar[key].snippet.replace(/^\w+ = /, ''), 'adds ' + api.sugar[key].class)];
    if (api.events[key]) {
        const args = (/^\(([^)]*)\)/.exec(api.events[key]) || [, ''])[1];
        return [item('function(' + args + ') end', K.Function, 'function(' + args + ')\n\t$0\nend')];
    }
    return [];
}

function enumFor(owner, key) {
    const cls = owner && (owner.kind === 'props' || owner.kind === 'sugar') ? owner.cls : '*';
    const p = propsOf(cls)[key] || allProps[key];
    return p && p.enum ? p : null;
}

const provider = {
    provideCompletionItems(document, position, _token, context) {
        const { text, stack, state, top } = contextAt(document, position);
        const trigger = context && context.triggerCharacter;

        if (state && (state.type === 'line' || state.comment)) return;
        if (state && state.type === 'str') {
            const before = text.slice(Math.max(0, state.start - 200), state.start);
            if (/(?:\bNew|\.New|\bnew|\.new|\.Create|IsA|OfClass|WhichIsA|GetClass)\s*\(?\s*$/.test(before)) return classItems();
            if (/OnEvent\s*\(?\s*$/.test(before)) return eventItems(true);
            if (/(?:OnChange|GetPropertyChangedSignal)\s*\(?\s*$/.test(before)) {
                const cls = top && top.owner.kind === 'props' ? top.owner.cls : '*';
                return propItems(cls, new Set(), false);
            }
            const m = /([A-Za-z_]\w*)\s*=\s*$/.exec(before);
            if (m) {
                const p = enumFor(top, m[1]);
                if (p) return api.enums[p.enum].map((v, i) => item(v, K.EnumMember, v, p.enum, null, String(i)));
            }
            return;
        }

        const line = document.lineAt(position).text.slice(0, position.character);
        let m;
        if ((m = /([A-Za-z_]\w*)\.(\w*)$/.exec(line))) {
            if (libNames(document).has(m[1])) {
                return Object.entries(api.members).map(([k, v]) =>
                    item(k, v.snippet ? K.Function : K.Field, v.snippet || k, 'Drawui', md([v.doc]), k));
            }
            const cls = variableClasses(document).get(m[1]);
            if (cls) return propItems(cls, new Set(), false).concat(eventItems(true));
            return;
        }
        if ((m = /[\w)\]]:(\w*)$/.exec(line))) {
            return Object.entries(api.methods).map(([k, v]) => item(k, K.Method, v, 'method'));
        }

        if (top) {
            const seg = text.slice(top.segStart);
            if ((m = /^\s*([A-Za-z_]\w*)\s*=\s*(\w*)$/.exec(seg))) return valueItems(top.owner, m[1]);
            if (trigger !== ' ' && trigger !== '=' && /^\s*[A-Za-z_]?\w*$/.test(seg)) return keyItems(document, top.owner, top.keys);
        }
    },
};

const hover = {
    provideHover(document, position) {
        const range = document.getWordRangeAtPosition(position, /[A-Za-z_]\w*/);
        if (!range) return;
        const word = document.getText(range);
        const { top } = contextAt(document, range.start);
        const owner = top ? top.owner : { kind: 'other' };
        const lineBefore = document.lineAt(position).text.slice(0, range.start.character);
        if (/([A-Za-z_]\w*)\.$/.test(lineBefore)) {
            const obj = /([A-Za-z_]\w*)\.$/.exec(lineBefore)[1];
            if (libNames(document).has(obj) && api.members[word]) return new vscode.Hover(md(['**' + obj + '.' + word + '**', api.members[word].doc]), range);
        }
        if (classes[word]) return new vscode.Hover(classDoc(word), range);
        if (api.sugar[word] && owner.kind === 'props') return new vscode.Hover(md(['**' + word + '** → ' + api.sugar[word].class, api.sugar[word].doc]), range);
        const cls = owner.kind === 'props' || owner.kind === 'sugar' ? owner.cls : null;
        const p = (cls && propsOf(cls)[word]) || (allProps[word] ? allProps[word] : null);
        if (p) return new vscode.Hover(propDoc(word, p, cls || classOfProp(word)), range);
        if (api.events[word]) return new vscode.Hover(md(['**' + word + '** (event) ' + api.events[word]]), range);
    },
};

function activate(context) {
    const selector = LANGS.map(language => ({ language }));
    context.subscriptions.push(
        vscode.languages.registerCompletionItemProvider(selector, provider, '"', "'", '.', ':', '=', ' '),
        vscode.languages.registerHoverProvider(selector, hover),
    );
}
function deactivate() {}

module.exports = { activate, deactivate };
