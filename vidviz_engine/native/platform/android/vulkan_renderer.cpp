/**
 * VidViz Engine - Vulkan Renderer Implementation (Android)
 * 
 * POC implementation - basic structure
 * Full Vulkan setup will be added incrementally
 */

#include "vulkan_renderer.h"
#include "common/log.h"

namespace vidviz {
namespace android {

VulkanRenderer::VulkanRenderer() {
    LOGI("VulkanRenderer created");
}

VulkanRenderer::~VulkanRenderer() {
    shutdown();
    LOGI("VulkanRenderer destroyed");
}

bool VulkanRenderer::initialize() {
    LOGI("Initializing Vulkan renderer...");

    if (!createInstance()) {
        cleanup();
        return false;
    }
    if (!selectPhysicalDevice()) {
        cleanup();
        return false;
    }
    if (!createLogicalDevice()) {
        cleanup();
        return false;
    }
    if (!createCommandPool()) {
        cleanup();
        return false;
    }
    
    LOGI("Vulkan renderer initialized");
    return true;
}

void VulkanRenderer::shutdown() {
    cleanup();
    LOGI("Vulkan renderer shutdown");
}

void VulkanRenderer::setOutputSize(int32_t width, int32_t height) {
    m_width = width;
    m_height = height;
    LOGI("Output size set: %dx%d", width, height);
    
    // Recreate swapchain if needed
    if (m_swapchain != VK_NULL_HANDLE) {
        // TODO: Recreate swapchain
    }
}

void VulkanRenderer::beginFrame() {
    // TODO: Acquire next swapchain image
    // vkAcquireNextImageKHR
}

GPUTexture VulkanRenderer::endFrame() {
    // TODO: Submit command buffer and present
    // vkQueueSubmit, vkQueuePresentKHR
    
    GPUTexture result;
    result.width = m_width;
    result.height = m_height;
    // result.handle = current frame image
    return result;
}

void VulkanRenderer::clear(float r, float g, float b, float a) {
    // TODO: Record clear command
}

void VulkanRenderer::renderMedia(const Asset& asset, TimeMs localTime) {
    // TODO: Decode video/image and render textured quad
    LOGV("renderMedia: %s @ %lld", asset.srcPath.c_str(), localTime);
}

void VulkanRenderer::renderText(const Asset& asset, TimeMs localTime) {
    // TODO: Render text using font atlas
    LOGV("renderText: %s @ %lld", asset.id.c_str(), localTime);
}

void VulkanRenderer::renderShader(const Asset& asset, ShaderManager* shaderManager, TimeMs localTime) {
    // TODO: Bind shader and render fullscreen quad
    LOGV("renderShader: %s @ %lld", asset.id.c_str(), localTime);
}

void VulkanRenderer::renderVisualizer(const Asset& asset, const std::vector<FFTData>& fftData, TimeMs localTime) {
    // TODO: Get FFT frame at localTime and render visualizer
    LOGV("renderVisualizer: %s @ %lld", asset.id.c_str(), localTime);
}

bool VulkanRenderer::compileShader(
    const std::string& shaderId,
    const std::string& vertexSource,
    const std::string& fragmentSource
) {
    // TODO: Compile GLSL → SPIR-V using shaderc
    LOGI("Compiling shader: %s", shaderId.c_str());
    return true;
}

void VulkanRenderer::bindShader(const std::string& shaderId) {
    // TODO: Bind pipeline
}

void VulkanRenderer::setUniform(const std::string& name, float value) {
    // TODO: Push constant or uniform buffer
}

void VulkanRenderer::setUniform(const std::string& name, float x, float y) {
    // TODO: Push constant or uniform buffer
}

void VulkanRenderer::setUniform(const std::string& name, float x, float y, float z) {
    // TODO: Push constant or uniform buffer
}

void VulkanRenderer::setUniform(const std::string& name, float x, float y, float z, float w) {
    // TODO: Push constant or uniform buffer
}

void VulkanRenderer::setUniform(const std::string& name, int value) {
    // TODO: Push constant or uniform buffer
}

void VulkanRenderer::setTexture(const std::string& name, const GPUTexture& texture, int unit) {
    // TODO: Bind texture to descriptor set
}

GPUTexture VulkanRenderer::loadTexture(const std::string& path) {
    // TODO: Load image and create VkImage
    LOGI("Loading texture: %s", path.c_str());
    GPUTexture tex;
    return tex;
}

void VulkanRenderer::unloadTexture(GPUTexture& texture) {
    // TODO: Destroy VkImage and free memory
}

NativeSurface VulkanRenderer::getEncoderSurface() {
    NativeSurface surface;
    surface.handle = m_nativeWindow;
    surface.width = m_width;
    surface.height = m_height;
    return surface;
}

void VulkanRenderer::setNativeWindow(ANativeWindow* window) {
    if (m_nativeWindow) {
        ANativeWindow_release(m_nativeWindow);
        m_nativeWindow = nullptr;
    }

    m_nativeWindow = window;
    if (m_nativeWindow) {
        ANativeWindow_acquire(m_nativeWindow);
    }
    LOGI("Native window set");
    
    if (window && m_device != VK_NULL_HANDLE) {
        createSwapchain();
        createRenderPass();
        createFramebuffers();
    }
}

// =============================================================================
// Vulkan Setup Helpers
// =============================================================================

bool VulkanRenderer::createInstance() {
    VkApplicationInfo appInfo = {};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "VidViz";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "VidVizEngine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_1;
    
    const char* extensions[] = {
        VK_KHR_SURFACE_EXTENSION_NAME,
        VK_KHR_ANDROID_SURFACE_EXTENSION_NAME,
    };
    
    VkInstanceCreateInfo createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledExtensionCount = 2;
    createInfo.ppEnabledExtensionNames = extensions;
    
#ifdef VIDVIZ_VULKAN_VALIDATION
    const char* validationLayers[] = {
        "VK_LAYER_KHRONOS_validation"
    };
    createInfo.enabledLayerCount = 1;
    createInfo.ppEnabledLayerNames = validationLayers;
#endif
    
    VkResult result = vkCreateInstance(&createInfo, nullptr, &m_instance);
    if (result != VK_SUCCESS) {
        LOGE("Failed to create Vulkan instance: %d", result);
        return false;
    }
    
    LOGI("Vulkan instance created");
    return true;
}

bool VulkanRenderer::selectPhysicalDevice() {
    uint32_t deviceCount = 0;
    vkEnumeratePhysicalDevices(m_instance, &deviceCount, nullptr);
    
    if (deviceCount == 0) {
        LOGE("No Vulkan devices found");
        return false;
    }
    
    std::vector<VkPhysicalDevice> devices(deviceCount);
    vkEnumeratePhysicalDevices(m_instance, &deviceCount, devices.data());
    
    // Just pick the first one for now
    m_physicalDevice = devices[0];
    
    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(m_physicalDevice, &props);
    LOGI("Selected GPU: %s", props.deviceName);
    
    return true;
}

bool VulkanRenderer::createLogicalDevice() {
    // Find graphics queue family
    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(m_physicalDevice, &queueFamilyCount, nullptr);
    
    std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(m_physicalDevice, &queueFamilyCount, queueFamilies.data());
    
    uint32_t graphicsFamily = UINT32_MAX;
    for (uint32_t i = 0; i < queueFamilyCount; i++) {
        if (queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
            graphicsFamily = i;
            break;
        }
    }
    
    if (graphicsFamily == UINT32_MAX) {
        LOGE("No graphics queue family found");
        return false;
    }
    
    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueCreateInfo = {};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = graphicsFamily;
    queueCreateInfo.queueCount = 1;
    queueCreateInfo.pQueuePriorities = &queuePriority;
    
    const char* deviceExtensions[] = {
        VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    };
    
    VkDeviceCreateInfo createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    createInfo.queueCreateInfoCount = 1;
    createInfo.pQueueCreateInfos = &queueCreateInfo;
    createInfo.enabledExtensionCount = 1;
    createInfo.ppEnabledExtensionNames = deviceExtensions;
    
    VkResult result = vkCreateDevice(m_physicalDevice, &createInfo, nullptr, &m_device);
    if (result != VK_SUCCESS) {
        LOGE("Failed to create logical device: %d", result);
        return false;
    }
    
    vkGetDeviceQueue(m_device, graphicsFamily, 0, &m_graphicsQueue);
    LOGI("Logical device created");
    
    return true;
}

bool VulkanRenderer::createSwapchain() {
    // TODO: Full swapchain creation
    LOGI("Swapchain creation (TODO)");
    return true;
}

bool VulkanRenderer::createRenderPass() {
    // TODO: Create render pass
    LOGI("Render pass creation (TODO)");
    return true;
}

bool VulkanRenderer::createFramebuffers() {
    // TODO: Create framebuffers
    LOGI("Framebuffer creation (TODO)");
    return true;
}

bool VulkanRenderer::createCommandPool() {
    // Get graphics queue family
    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(m_physicalDevice, &queueFamilyCount, nullptr);
    
    std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(m_physicalDevice, &queueFamilyCount, queueFamilies.data());
    
    uint32_t graphicsFamily = 0;
    for (uint32_t i = 0; i < queueFamilyCount; i++) {
        if (queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
            graphicsFamily = i;
            break;
        }
    }
    
    VkCommandPoolCreateInfo poolInfo = {};
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    poolInfo.queueFamilyIndex = graphicsFamily;
    poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    
    VkResult result = vkCreateCommandPool(m_device, &poolInfo, nullptr, &m_commandPool);
    if (result != VK_SUCCESS) {
        LOGE("Failed to create command pool: %d", result);
        return false;
    }
    
    LOGI("Command pool created");
    return true;
}

void VulkanRenderer::cleanup() {
    if (m_nativeWindow) {
        ANativeWindow_release(m_nativeWindow);
        m_nativeWindow = nullptr;
    }

    if (m_device != VK_NULL_HANDLE) {
        vkDeviceWaitIdle(m_device);

        if (m_commandPool != VK_NULL_HANDLE) {
            vkDestroyCommandPool(m_device, m_commandPool, nullptr);
            m_commandPool = VK_NULL_HANDLE;
        }

        for (auto fb : m_framebuffers) {
            if (fb != VK_NULL_HANDLE) {
                vkDestroyFramebuffer(m_device, fb, nullptr);
            }
        }
        m_framebuffers.clear();

        for (auto iv : m_swapchainImageViews) {
            if (iv != VK_NULL_HANDLE) {
                vkDestroyImageView(m_device, iv, nullptr);
            }
        }
        m_swapchainImageViews.clear();

        if (m_renderPass != VK_NULL_HANDLE) {
            vkDestroyRenderPass(m_device, m_renderPass, nullptr);
            m_renderPass = VK_NULL_HANDLE;
        }

        if (m_swapchain != VK_NULL_HANDLE) {
            vkDestroySwapchainKHR(m_device, m_swapchain, nullptr);
            m_swapchain = VK_NULL_HANDLE;
        }

        vkDestroyDevice(m_device, nullptr);
        m_device = VK_NULL_HANDLE;
    }

    if (m_surface != VK_NULL_HANDLE && m_instance != VK_NULL_HANDLE) {
        vkDestroySurfaceKHR(m_instance, m_surface, nullptr);
        m_surface = VK_NULL_HANDLE;
    }

    if (m_instance != VK_NULL_HANDLE) {
        vkDestroyInstance(m_instance, nullptr);
        m_instance = VK_NULL_HANDLE;
    }
}

} // namespace android
} // namespace vidviz
