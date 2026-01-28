/**
 * VidViz Engine - Timeline
 * 
 * Zaman tabanlı timeline yönetimi.
 * Seek işlemi "frame++" yaparak değil, "time = new_time" diyerek yapılır.
 */

#pragma once

#include "common/types.h"
#include <vector>

namespace vidviz {

/**
 * Timeline Manager
 * 
 * Time-based, NOT frame-based!
 * Audio varsa, audio clock = master
 */
class Timeline {
public:
    Timeline();
    ~Timeline();

    /// Set total duration
    void setDuration(TimeMs duration);

    /// Get total duration
    TimeMs getDuration() const { return m_duration; }

    /// Seek to specific time (instantaneous state transfer)
    void seek(TimeMs timeMs);

    /// Get current time
    TimeMs getCurrentTime() const { return m_currentTime; }

    /// Get active assets at current time
    std::vector<const Asset*> getActiveAssets(const std::vector<Layer>& layers) const;

    /// Check if asset is active at given time
    static bool isAssetActive(const Asset& asset, TimeMs timeMs);

    /// Calculate local time within asset
    static TimeMs getLocalTime(const Asset& asset, TimeMs globalTime);

private:
    TimeMs m_duration{0};
    TimeMs m_currentTime{0};
};

} // namespace vidviz
