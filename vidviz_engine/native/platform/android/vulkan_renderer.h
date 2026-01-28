/**
 * VidViz Engine - Vulkan Renderer (Android)
 * 
 * Android'e özel Vulkan kurulumu.
 * Vulkan image → ANativeWindow
 * GPU → CPU kopyasından kaçın!
 */

#pragma once

#include "platform/renderer_interface.h"

// Vulkan headers - Android extension için özel sıralama
#define VK_USE_PLATFORM_ANDROID_KHR
#include <vulkan/vulkan.h>

#include <android/native_window.h>

namespace vidviz {
namespace android {

/**
 * Vulkan Renderer for Android
 * 
 * PERFORMANS KURALLARI:
 * - Triple buffering kullan
 * - AHardwareBuffer tercih et
 * - GPU → CPU kopyasından kaçın
 */
class VulkanRenderer : public RendererInterface {
public:
    VulkanRenderer();
    ~VulkanRenderer() override;

    // RendererInterface implementation
    bool initialize() override;
    void shutdown() override;
    void setOutputSize(int32_t width, int32_t height) override;
    void beginFrame() override;
    GPUTexture endFrame() override;
    void clear(float r, float g, float b, float a) override;
    void renderMedia(const Asset& asset, TimeMs localTime) override;
    void renderText(const Asset& asset, TimeMs localTime) override;
    void renderShader(const Asset& asset, ShaderManager* shaderManager, TimeMs localTime) override;
    void renderVisualizer(const Asset& asset, const std::vector<FFTData>& fftData, TimeMs localTime) override;
    bool compileShader(const std::string& shaderId, const std::string& vertexSource, const std::string& fragmentSource) override;
    void bindShader(const std::string& shaderId) override;
    void setUniform(const std::string& name, float value) override;
    void setUniform(const std::string& name, float x, float y) override;
    void setUniform(const std::string& name, float x, float y, float z) override;
    void setUniform(const std::string& name, float x, float y, float z, float w) override;
    void setUniform(const std::string& name, int value) override;
    void setTexture(const std::string& name, const GPUTexture& texture, int unit) override;
    GPUTexture loadTexture(const std::string& path) override;
    void unloadTexture(GPUTexture& texture) override;
    NativeSurface getEncoderSurface() override;

    // Android specific
    void setNativeWindow(ANativeWindow* window);

private:
    // Vulkan components
    VkInstance m_instance = VK_NULL_HANDLE;
    VkPhysicalDevice m_physicalDevice = VK_NULL_HANDLE;
    VkDevice m_device = VK_NULL_HANDLE;
    VkQueue m_graphicsQueue = VK_NULL_HANDLE;
    VkCommandPool m_commandPool = VK_NULL_HANDLE;
    VkSurfaceKHR m_surface = VK_NULL_HANDLE;
    VkSwapchainKHR m_swapchain = VK_NULL_HANDLE;
    
    // Render targets
    std::vector<VkImage> m_swapchainImages;
    std::vector<VkImageView> m_swapchainImageViews;
    std::vector<VkFramebuffer> m_framebuffers;
    
    // Pipeline
    VkRenderPass m_renderPass = VK_NULL_HANDLE;
    VkPipelineLayout m_pipelineLayout = VK_NULL_HANDLE;
    
    // Current frame
    uint32_t m_currentFrame = 0;
    uint32_t m_imageIndex = 0;
    
    // Output size
    int32_t m_width = 1920;
    int32_t m_height = 1080;
    
    // Native window
    ANativeWindow* m_nativeWindow = nullptr;

    // Helper methods
    bool createInstance();
    bool selectPhysicalDevice();
    bool createLogicalDevice();
    bool createSwapchain();
    bool createRenderPass();
    bool createFramebuffers();
    bool createCommandPool();
    void cleanup();
};

} // namespace android
} // namespace vidviz
