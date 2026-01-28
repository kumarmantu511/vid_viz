#include "minijson.h"

#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sstream>

namespace vidviz::minijson {

namespace {

struct Cursor {
    const char* p;
    const char* end;
};

static void skipWs(Cursor* c) {
    while (c->p < c->end) {
        const unsigned char ch = static_cast<unsigned char>(*c->p);
        if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
            ++c->p;
            continue;
        }
        break;
    }
}

static bool consume(Cursor* c, char ch) {
    skipWs(c);
    if (c->p < c->end && *c->p == ch) {
        ++c->p;
        return true;
    }
    return false;
}

static bool parseString(Cursor* c, std::string* out, std::string* err) {
    skipWs(c);
    if (c->p >= c->end || *c->p != '"') {
        *err = "Expected string";
        return false;
    }
    ++c->p;

    std::string s;
    while (c->p < c->end) {
        const char ch = *c->p++;
        if (ch == '"') {
            *out = std::move(s);
            return true;
        }
        if (ch == '\\') {
            if (c->p >= c->end) {
                *err = "Unterminated escape";
                return false;
            }
            const char esc = *c->p++;
            switch (esc) {
                case '"': s.push_back('"'); break;
                case '\\': s.push_back('\\'); break;
                case '/': s.push_back('/'); break;
                case 'b': s.push_back('\b'); break;
                case 'f': s.push_back('\f'); break;
                case 'n': s.push_back('\n'); break;
                case 'r': s.push_back('\r'); break;
                case 't': s.push_back('\t'); break;
                case 'u':
                    *err = "\\uXXXX not supported";
                    return false;
                default:
                    *err = "Invalid escape";
                    return false;
            }
        } else {
            s.push_back(ch);
        }
    }

    *err = "Unterminated string";
    return false;
}

static bool parseNumber(Cursor* c, double* out, std::string* err) {
    skipWs(c);
    const char* start = c->p;
    if (start >= c->end) {
        *err = "Expected number";
        return false;
    }

    if (*c->p == '-') ++c->p;

    bool any = false;
    while (c->p < c->end && std::isdigit(static_cast<unsigned char>(*c->p))) {
        any = true;
        ++c->p;
    }

    if (c->p < c->end && *c->p == '.') {
        ++c->p;
        while (c->p < c->end && std::isdigit(static_cast<unsigned char>(*c->p))) {
            any = true;
            ++c->p;
        }
    }

    if (c->p < c->end && (*c->p == 'e' || *c->p == 'E')) {
        ++c->p;
        if (c->p < c->end && (*c->p == '+' || *c->p == '-')) ++c->p;
        bool expAny = false;
        while (c->p < c->end && std::isdigit(static_cast<unsigned char>(*c->p))) {
            expAny = true;
            ++c->p;
        }
        if (!expAny) {
            *err = "Invalid exponent";
            return false;
        }
    }

    if (!any) {
        *err = "Invalid number";
        return false;
    }

    std::string tmp(start, c->p);
    char* endPtr = nullptr;
    const double v = std::strtod(tmp.c_str(), &endPtr);
    if (endPtr == tmp.c_str()) {
        *err = "Invalid number";
        return false;
    }
    *out = v;
    return true;
}

static bool parseValue(Cursor* c, Value* out, std::string* err);

static bool parseArray(Cursor* c, Value::Array* out, std::string* err) {
    if (!consume(c, '[')) {
        *err = "Expected '['";
        return false;
    }

    Value::Array arr;
    skipWs(c);
    if (consume(c, ']')) {
        *out = std::move(arr);
        return true;
    }

    while (true) {
        Value v;
        if (!parseValue(c, &v, err)) return false;
        arr.push_back(std::move(v));

        skipWs(c);
        if (consume(c, ']')) break;
        if (!consume(c, ',')) {
            *err = "Expected ',' or ']'";
            return false;
        }
    }

    *out = std::move(arr);
    return true;
}

static bool parseObject(Cursor* c, Value::Object* out, std::string* err) {
    if (!consume(c, '{')) {
        *err = "Expected '{'";
        return false;
    }

    Value::Object obj;
    skipWs(c);
    if (consume(c, '}')) {
        *out = std::move(obj);
        return true;
    }

    while (true) {
        std::string key;
        if (!parseString(c, &key, err)) return false;
        if (!consume(c, ':')) {
            *err = "Expected ':'";
            return false;
        }
        Value v;
        if (!parseValue(c, &v, err)) return false;
        obj.emplace(std::move(key), std::move(v));

        skipWs(c);
        if (consume(c, '}')) break;
        if (!consume(c, ',')) {
            *err = "Expected ',' or '}'";
            return false;
        }
    }

    *out = std::move(obj);
    return true;
}

static bool parseLiteral(Cursor* c, const char* lit) {
    const size_t n = std::strlen(lit);
    if (static_cast<size_t>(c->end - c->p) < n) return false;
    if (std::strncmp(c->p, lit, n) != 0) return false;
    c->p += n;
    return true;
}

static bool parseValue(Cursor* c, Value* out, std::string* err) {
    skipWs(c);
    if (c->p >= c->end) {
        *err = "Unexpected end";
        return false;
    }

    const char ch = *c->p;
    if (ch == '{') {
        Value::Object obj;
        if (!parseObject(c, &obj, err)) return false;
        *out = Value(std::move(obj));
        return true;
    }
    if (ch == '[') {
        Value::Array arr;
        if (!parseArray(c, &arr, err)) return false;
        *out = Value(std::move(arr));
        return true;
    }
    if (ch == '"') {
        std::string s;
        if (!parseString(c, &s, err)) return false;
        *out = Value(std::move(s));
        return true;
    }
    if (ch == '-' || std::isdigit(static_cast<unsigned char>(ch))) {
        double num = 0.0;
        if (!parseNumber(c, &num, err)) return false;
        *out = Value(num);
        return true;
    }

    if (parseLiteral(c, "true")) {
        *out = Value(true);
        return true;
    }
    if (parseLiteral(c, "false")) {
        *out = Value(false);
        return true;
    }
    if (parseLiteral(c, "null")) {
        *out = Value(nullptr);
        return true;
    }

    *err = "Unexpected token";
    return false;
}

static void escapeString(const std::string& s, std::string* out) {
    out->push_back('"');
    for (const char ch : s) {
        switch (ch) {
            case '\\': out->append("\\\\"); break;
            case '"': out->append("\\\""); break;
            case '\n': out->append("\\n"); break;
            case '\r': out->append("\\r"); break;
            case '\t': out->append("\\t"); break;
            default: out->push_back(ch); break;
        }
    }
    out->push_back('"');
}

static void stringifyImpl(const Value& v, std::string* out) {
    if (v.isNull()) {
        out->append("null");
        return;
    }
    if (const bool* b = v.asBool()) {
        out->append(*b ? "true" : "false");
        return;
    }
    if (const double* n = v.asNumber()) {
        char buf[64];
        std::snprintf(buf, sizeof(buf), "%.17g", *n);
        out->append(buf);
        return;
    }
    if (const std::string* s = v.asString()) {
        escapeString(*s, out);
        return;
    }
    if (const Value::Array* a = v.asArray()) {
        out->push_back('[');
        for (size_t i = 0; i < a->size(); ++i) {
            if (i > 0) out->push_back(',');
            stringifyImpl((*a)[i], out);
        }
        out->push_back(']');
        return;
    }
    if (const Value::Object* o = v.asObject()) {
        out->push_back('{');
        bool first = true;
        for (const auto& kv : *o) {
            if (!first) out->push_back(',');
            first = false;
            escapeString(kv.first, out);
            out->push_back(':');
            stringifyImpl(kv.second, out);
        }
        out->push_back('}');
        return;
    }
}

} // namespace

ParseResult parse(const std::string& text) {
    ParseResult r;
    Cursor c{ text.data(), text.data() + text.size() };

    std::string err;
    Value v;
    if (!parseValue(&c, &v, &err)) {
        r.error = err;
        return r;
    }

    skipWs(&c);
    if (c.p != c.end) {
        r.error = "Trailing characters";
        return r;
    }

    r.value = std::move(v);
    return r;
}

std::string stringify(const Value& value) {
    std::string out;
    out.reserve(256);
    stringifyImpl(value, &out);
    return out;
}

const Value* get(const Value::Object& obj, const std::string& key) {
    auto it = obj.find(key);
    if (it == obj.end()) return nullptr;
    return &it->second;
}

bool getString(const Value::Object& obj, const std::string& key, std::string* out) {
    const Value* v = get(obj, key);
    if (!v) return false;
    const std::string* s = v->asString();
    if (!s) return false;
    *out = *s;
    return true;
}

bool getBool(const Value::Object& obj, const std::string& key, bool* out) {
    const Value* v = get(obj, key);
    if (!v) return false;
    const bool* b = v->asBool();
    if (!b) return false;
    *out = *b;
    return true;
}

bool getDouble(const Value::Object& obj, const std::string& key, double* out) {
    const Value* v = get(obj, key);
    if (!v) return false;
    const double* n = v->asNumber();
    if (!n) return false;
    *out = *n;
    return true;
}

bool getInt64(const Value::Object& obj, const std::string& key, int64_t* out) {
    double d;
    if (!getDouble(obj, key, &d)) return false;
    *out = static_cast<int64_t>(d);
    return true;
}

} // namespace vidviz::minijson
