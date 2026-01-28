#pragma once

#include <cstdint>
#include <string>
#include <unordered_map>
#include <variant>
#include <vector>

namespace vidviz::minijson {

struct Value {
    using Object = std::unordered_map<std::string, Value>;
    using Array = std::vector<Value>;
    using Storage = std::variant<std::nullptr_t, bool, double, std::string, Object, Array>;

    Storage v;

    Value() : v(nullptr) {}
    Value(std::nullptr_t) : v(nullptr) {}
    Value(bool b) : v(b) {}
    Value(double n) : v(n) {}
    Value(std::string s) : v(std::move(s)) {}
    Value(Object o) : v(std::move(o)) {}
    Value(Array a) : v(std::move(a)) {}

    bool isNull() const { return std::holds_alternative<std::nullptr_t>(v); }
    bool isBool() const { return std::holds_alternative<bool>(v); }
    bool isNumber() const { return std::holds_alternative<double>(v); }
    bool isString() const { return std::holds_alternative<std::string>(v); }
    bool isObject() const { return std::holds_alternative<Object>(v); }
    bool isArray() const { return std::holds_alternative<Array>(v); }

    const bool* asBool() const { return std::get_if<bool>(&v); }
    const double* asNumber() const { return std::get_if<double>(&v); }
    const std::string* asString() const { return std::get_if<std::string>(&v); }
    const Object* asObject() const { return std::get_if<Object>(&v); }
    const Array* asArray() const { return std::get_if<Array>(&v); }
};

struct ParseResult {
    Value value;
    std::string error;

    bool ok() const { return error.empty(); }
};

ParseResult parse(const std::string& text);
std::string stringify(const Value& value);

const Value* get(const Value::Object& obj, const std::string& key);

bool getString(const Value::Object& obj, const std::string& key, std::string* out);
bool getBool(const Value::Object& obj, const std::string& key, bool* out);
bool getDouble(const Value::Object& obj, const std::string& key, double* out);
bool getInt64(const Value::Object& obj, const std::string& key, int64_t* out);

} // namespace vidviz::minijson
