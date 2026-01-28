#include "platform/android/renderer/gles/shader_source_utils.h"

#include <string>

namespace vidviz {
    namespace android {
        namespace gles {

            namespace {

                static std::string trimLeft(const std::string& s) {
                    size_t i = 0;
                    while (i < s.size() && (s[i] == ' ' || s[i] == '\t' || s[i] == '\r')) i++;
                    return s.substr(i);
                }

                static void replaceAll(std::string& s, const std::string& from, const std::string& to) {
                    if (from.empty()) return;
                    size_t pos = 0;
                    while ((pos = s.find(from, pos)) != std::string::npos) {
                        s.replace(pos, from.size(), to);
                        pos += to.size();
                    }
                }

            } // namespace

            std::string toGles3FragmentSource(std::string src) {
                std::string header;
                header.reserve(src.size() + 512);
                std::string body;
                body.reserve(src.size() + 512);

                header += "#version 300 es\n";
                header += "precision highp float;\n";
                header += "uniform vec2 uResolution;\n";
                header += "in vec2 vUV;\n";
                header += "out vec4 fragColor;\n";
                header += "vec4 FlutterFragCoord(){ return vec4(vUV.x * uResolution.x, (1.0 - vUV.y) * uResolution.y, 0.0, 1.0); }\n";
                header += "vec4 vvTexture(sampler2D s, vec2 uv){ return texture(s, vec2(uv.x, 1.0 - uv.y)); }\n"; 

                {
                    size_t start = 0;
                    while (start < src.size()) {
                        size_t end = src.find('\n', start);
                        if (end == std::string::npos) end = src.size();
                        std::string line = src.substr(start, end - start);
                        const std::string tl = trimLeft(line);
                        if (tl.rfind("#version", 0) == 0 || tl.rfind("#include", 0) == 0) {
                        } else if (tl.rfind("#extension", 0) == 0) {
                        } else if (tl.rfind("precision", 0) == 0) {
                        } else if (tl.rfind("out vec4 fragColor", 0) == 0 || tl.rfind("out highp vec4 fragColor", 0) == 0 ||
                                   tl.rfind("out mediump vec4 fragColor", 0) == 0) {
                        } else if (tl.rfind("uniform vec2 uResolution", 0) == 0 || tl.rfind("uniform highp vec2 uResolution", 0) == 0 ||
                                   tl.rfind("uniform mediump vec2 uResolution", 0) == 0) {
                        } else if (tl.rfind("varying vec2 vUV", 0) == 0 || tl.rfind("varying highp vec2 vUV", 0) == 0 ||
                                   tl.rfind("varying mediump vec2 vUV", 0) == 0) {
                        } else if (tl.rfind("in vec2 vUV", 0) == 0 || tl.rfind("in highp vec2 vUV", 0) == 0 ||
                                   tl.rfind("in mediump vec2 vUV", 0) == 0) {
                        } else {
                            body += line;
                            body += "\n";
                        }
                        start = (end < src.size()) ? (end + 1) : end;
                    }
                }

                // Only flip Y for scene/FBO sampling (uTexture/uTex/iChannel0).
                // Bitmap textures (uploaded from CPU) should remain unflipped to match Flutter UI.
                replaceAll(body, "texture2D(uTexture", "vvTexture(uTexture");
                replaceAll(body, "texture2D( uTexture", "vvTexture(uTexture");
                replaceAll(body, "texture2D(uTex", "vvTexture(uTex");
                replaceAll(body, "texture2D( uTex", "vvTexture(uTex");
                replaceAll(body, "texture2D(iChannel0", "vvTexture(iChannel0");
                replaceAll(body, "texture2D( iChannel0", "vvTexture(iChannel0");
                replaceAll(body, "texture(uTexture", "vvTexture(uTexture");
                replaceAll(body, "texture( uTexture", "vvTexture(uTexture");
                replaceAll(body, "texture(uTex", "vvTexture(uTex");
                replaceAll(body, "texture( uTex", "vvTexture(uTex");
                replaceAll(body, "texture(iChannel0", "vvTexture(iChannel0");
                replaceAll(body, "texture( iChannel0", "vvTexture(iChannel0");
                replaceAll(body, "gl_FragColor", "fragColor");
                return header + body;
            }

            std::string toGles3TextEffectFragmentSource(std::string src) {
                std::string header;
                header.reserve(src.size() + 512);
                std::string body;
                body.reserve(src.size() + 512);

                header += "#version 300 es\n";
                header += "precision highp float;\n";
                header += "uniform vec2 uResolution;\n";
                header += "in vec2 vUV;\n";
                header += "out vec4 fragColor;\n";
                header += "uniform sampler2D uMask;\n";
                header += "uniform float uAlpha;\n";
                header += "vec4 FlutterFragCoord(){ return vec4(vUV.x * uResolution.x, (1.0 - vUV.y) * uResolution.y, 0.0, 1.0); }\n";
                header += "vec4 vvTexture(sampler2D s, vec2 uv){ return texture(s, vec2(uv.x, 1.0 - uv.y)); }\n";

                {
                    size_t start = 0;
                    while (start < src.size()) {
                        size_t end = src.find('\n', start);
                        if (end == std::string::npos) end = src.size();
                        std::string line = src.substr(start, end - start);
                        const std::string tl = trimLeft(line);
                        if (tl.rfind("#version", 0) == 0 || tl.rfind("#include", 0) == 0) {
                        } else if (tl.rfind("#extension", 0) == 0) {
                        } else if (tl.rfind("precision", 0) == 0) {
                        } else if (tl.rfind("out vec4 fragColor", 0) == 0 || tl.rfind("out highp vec4 fragColor", 0) == 0 ||
                                   tl.rfind("out mediump vec4 fragColor", 0) == 0) {
                        } else if (tl.rfind("uniform vec2 uResolution", 0) == 0 || tl.rfind("uniform highp vec2 uResolution", 0) == 0 ||
                                   tl.rfind("uniform mediump vec2 uResolution", 0) == 0) {
                        } else if (tl.rfind("varying vec2 vUV", 0) == 0 || tl.rfind("varying highp vec2 vUV", 0) == 0 ||
                                   tl.rfind("varying mediump vec2 vUV", 0) == 0) {
                        } else if (tl.rfind("in vec2 vUV", 0) == 0 || tl.rfind("in highp vec2 vUV", 0) == 0 ||
                                   tl.rfind("in mediump vec2 vUV", 0) == 0) {
                        } else if (tl.rfind("uniform sampler2D uMask", 0) == 0) {
                        } else if (tl.rfind("uniform float uAlpha", 0) == 0) {
                        } else {
                            body += line;
                            body += "\n";
                        }
                        start = (end < src.size()) ? (end + 1) : end;
                    }
                }

                // Only flip Y for scene/FBO sampling (uTexture/uTex/iChannel0).
                // Bitmap textures (uploaded from CPU) should remain unflipped to match Flutter UI.
                replaceAll(body, "texture2D(uTexture", "vvTexture(uTexture");
                replaceAll(body, "texture2D( uTexture", "vvTexture(uTexture");
                replaceAll(body, "texture2D(uTex", "vvTexture(uTex");
                replaceAll(body, "texture2D( uTex", "vvTexture(uTex");
                replaceAll(body, "texture2D(iChannel0", "vvTexture(iChannel0");
                replaceAll(body, "texture2D( iChannel0", "vvTexture(iChannel0");
                replaceAll(body, "texture(uTexture", "vvTexture(uTexture");
                replaceAll(body, "texture( uTexture", "vvTexture(uTexture");
                replaceAll(body, "texture(uTex", "vvTexture(uTex");
                replaceAll(body, "texture( uTex", "vvTexture(uTex");
                replaceAll(body, "texture(iChannel0", "vvTexture(iChannel0");
                replaceAll(body, "texture( iChannel0", "vvTexture(iChannel0");
                replaceAll(body, "gl_FragColor", "fragColor");

                const std::string needle = "void main";
                const size_t pos = body.find(needle);
                if (pos != std::string::npos) {
                    body.replace(pos, needle.size(), "void vv_user_main");
                }

                body += "\nvoid main(){\n";
                body += "  vv_user_main();\n";
                body += "  float m = vvTexture(uMask, vUV).a;\n";
                body += "  fragColor = vec4(fragColor.rgb * m, fragColor.a * m * uAlpha);\n";
                body += "}\n";

                return header + body;
            }

        } // namespace gles
    } // namespace android
} // namespace vidviz