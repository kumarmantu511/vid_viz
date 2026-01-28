/**
 * VidViz Engine - Shader Manager
 * 
 * GLSL shader yönetim merkezi.
 * Tek GLSL kaynak - platform dönüşümü bridge'de yapılır.
 */

#pragma once

#include "common/types.h"
#include <unordered_map>
#include <string>

namespace vidviz {

/**
 * Shader Manager
 * 
 * Shader'lar tek GLSL kaynak olarak tutulur.
 * Android: GLSL → SPIR-V (at build time or runtime via shaderc)
 * iOS: SPIR-V → Metal (via SPIRV-Cross)
 */
class ShaderManager {
public:
    ShaderManager();
    ~ShaderManager();

    /// Compile and cache shader from source
    bool compileShader(const ShaderProgram& shader);

    /// Get compiled shader by ID
    const ShaderProgram* getShader(const std::string& id) const;

    /// Check if shader exists
    bool hasShader(const std::string& id) const;

    /// Remove shader
    void removeShader(const std::string& id);

    /// Clear all shaders
    void clearAll();

    /// Get all shader IDs
    std::vector<std::string> getShaderIds() const;

    /// Set uniform value (cached for next render)
    void setUniform(const std::string& shaderId, const std::string& name, float value);
    void setUniform(const std::string& shaderId, const std::string& name, float x, float y);
    void setUniform(const std::string& shaderId, const std::string& name, float x, float y, float z);
    void setUniform(const std::string& shaderId, const std::string& name, float x, float y, float z, float w);

private:
    /// Cached shaders
    std::unordered_map<std::string, ShaderProgram> m_shaders;

    /// Cached uniform values per shader
    std::unordered_map<std::string, std::unordered_map<std::string, std::vector<float>>> m_uniforms;
};

} // namespace vidviz
