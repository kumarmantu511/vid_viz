/**
 * VidViz Engine - Effect Base Class
 * 
 * Abstract base for all visual effects.
 */

#pragma once

#include "common/types.h"

namespace vidviz {

/**
 * Base Effect Interface
 */
class Effect {
public:
    virtual ~Effect() = default;

    /// Get effect type name
    virtual const char* getTypeName() const = 0;

    /// Apply effect at given time
    virtual void apply(TimeMs timeMs) = 0;

    /// Get output texture
    virtual GPUTexture getOutput() const = 0;
};

} // namespace vidviz
