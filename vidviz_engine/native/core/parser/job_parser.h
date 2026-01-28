/**
 * VidViz Engine - Job Parser
 * 
 * JSON Job okuyucu.
 * Flutter'dan gelen JSON job'u C++ struct'lara dönüştürür.
 */

#pragma once

#include "common/types.h"
#include <memory>
#include <string>

namespace vidviz {

/**
 * Job Parser
 * 
 * JSON string → ExportJob struct
 */
class JobParser {
public:
    JobParser();
    ~JobParser();

    /// Parse JSON string to ExportJob
    std::unique_ptr<ExportJob> parse(const std::string& json);

private:
    /// Parse video settings
    VideoSettings parseSettings(const void* settingsObj);

    /// Parse layer
    Layer parseLayer(const void* layerObj);

    /// Parse asset
    Asset parseAsset(const void* assetObj);

    /// Parse shader program
    ShaderProgram parseShader(const void* shaderObj);

    /// Parse FFT data
    FFTData parseFFTData(const void* fftObj);

    /// Get asset type from string
    AssetType parseAssetType(const std::string& typeStr);

    /// Get layer type from string
    LayerType parseLayerType(const std::string& typeStr);
};

} // namespace vidviz
