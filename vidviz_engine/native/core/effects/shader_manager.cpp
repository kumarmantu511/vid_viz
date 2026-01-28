/**
 * VidViz Engine - Shader Manager Implementation
 */

#include "shader_manager.h"
#include "common/log.h"

namespace vidviz {

ShaderManager::ShaderManager() {
    LOGD("ShaderManager created");
}

ShaderManager::~ShaderManager() {
    clearAll();
    LOGD("ShaderManager destroyed");
}

bool ShaderManager::compileShader(const ShaderProgram& shader) {
    if (shader.id.empty()) {
        LOGE("Shader ID is empty");
        return false;
    }

    if (shader.fragmentSource.empty()) {
        LOGE("Shader has no fragment source: %s", shader.id.c_str());
        return false;
    }

    // Store shader (actual compilation happens in platform renderer)
    m_shaders[shader.id] = shader;
    
    // Initialize uniform cache
    m_uniforms[shader.id] = {};
    for (const auto& uniform : shader.uniforms) {
        m_uniforms[shader.id][uniform.name] = uniform.values;
    }

    LOGI("Shader registered: %s", shader.id.c_str());
    return true;
}

const ShaderProgram* ShaderManager::getShader(const std::string& id) const {
    auto it = m_shaders.find(id);
    if (it != m_shaders.end()) {
        return &it->second;
    }
    return nullptr;
}

bool ShaderManager::hasShader(const std::string& id) const {
    return m_shaders.find(id) != m_shaders.end();
}

void ShaderManager::removeShader(const std::string& id) {
    m_shaders.erase(id);
    m_uniforms.erase(id);
}

void ShaderManager::clearAll() {
    m_shaders.clear();
    m_uniforms.clear();
    LOGD("All shaders cleared");
}

std::vector<std::string> ShaderManager::getShaderIds() const {
    std::vector<std::string> ids;
    ids.reserve(m_shaders.size());
    for (const auto& pair : m_shaders) {
        ids.push_back(pair.first);
    }
    return ids;
}

void ShaderManager::setUniform(const std::string& shaderId, const std::string& name, float value) {
    m_uniforms[shaderId][name] = {value};
}

void ShaderManager::setUniform(const std::string& shaderId, const std::string& name, float x, float y) {
    m_uniforms[shaderId][name] = {x, y};
}

void ShaderManager::setUniform(const std::string& shaderId, const std::string& name, float x, float y, float z) {
    m_uniforms[shaderId][name] = {x, y, z};
}

void ShaderManager::setUniform(const std::string& shaderId, const std::string& name, float x, float y, float z, float w) {
    m_uniforms[shaderId][name] = {x, y, z, w};
}

} // namespace vidviz
