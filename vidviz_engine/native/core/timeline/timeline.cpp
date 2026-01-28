/**
 * VidViz Engine - Timeline Implementation
 */

#include "timeline.h"

namespace vidviz {

Timeline::Timeline() = default;
Timeline::~Timeline() = default;

void Timeline::setDuration(TimeMs duration) {
    m_duration = duration;
}

void Timeline::seek(TimeMs timeMs) {
    // Time-based seek - instant state transfer
    // NOT frame++, but time = new_time
    if (timeMs < 0) timeMs = 0;
    if (timeMs > m_duration) timeMs = m_duration;
    m_currentTime = timeMs;
}

std::vector<const Asset*> Timeline::getActiveAssets(const std::vector<Layer>& layers) const {
    std::vector<const Asset*> activeAssets;
    
    for (const auto& layer : layers) {
        for (const auto& asset : layer.assets) {
            if (isAssetActive(asset, m_currentTime)) {
                activeAssets.push_back(&asset);
            }
        }
    }
    
    return activeAssets;
}

bool Timeline::isAssetActive(const Asset& asset, TimeMs timeMs) {
    return timeMs >= asset.begin && timeMs < (asset.begin + asset.duration);
}

TimeMs Timeline::getLocalTime(const Asset& asset, TimeMs globalTime) {
    // Local time = position within asset + cutFrom offset
    // Respects playback speed
    TimeMs relativeTime = globalTime - asset.begin;
    float speed = asset.playbackSpeed > 0 ? asset.playbackSpeed : 1.0f;
    return asset.cutFrom + static_cast<TimeMs>(relativeTime * speed);
}

} // namespace vidviz
