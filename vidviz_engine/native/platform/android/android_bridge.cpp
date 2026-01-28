/**
 * VidViz Engine - Android Bridge
 * 
 * Android JNI köprüsü.
 * İNCE köprü - iş mantığı YOK!
 * Sadece "tuvali" (Surface) kurup Core'a verir.
 */

#include "core/engine.h"
#include "common/log.h"
#include "platform/android/renderer/gles/text_rasterizer.h"

#include <jni.h>
#include <android/native_window_jni.h>
 #include <dlfcn.h>

namespace vidviz {
namespace android {

JavaVM* g_vidvizJvm = nullptr;

JavaVM* getJavaVmFallback() {
    if (g_vidvizJvm) return g_vidvizJvm;
    using JNI_GetCreatedJavaVMsFn = jint (*)(JavaVM**, jsize, jsize*);
    auto* fn = reinterpret_cast<JNI_GetCreatedJavaVMsFn>(dlsym(RTLD_DEFAULT, "JNI_GetCreatedJavaVMs"));
    if (!fn) return nullptr;

    JavaVM* vms[1] = {nullptr};
    jsize count = 0;
    const jint res = fn(vms, 1, &count);
    if (res == JNI_OK && count > 0 && vms[0]) g_vidvizJvm = vms[0];
    return g_vidvizJvm;
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
    g_vidvizJvm = vm;
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM*, void*) {
    gles::shutdownTextRasterizer();
}

/**
 * Initialize platform-specific components
 */
extern "C" JNIEXPORT jlong JNICALL
Java_com_vidviz_engine_VidvizEnginePlugin_nativeInit(
    JNIEnv* env,
    jobject /* this */
) {
    LOGI("Android bridge: nativeInit");

    if (!g_vidvizJvm && env) {
        env->GetJavaVM(&g_vidvizJvm);
    }

    void* handle = vidviz_engine_init();
    if (!handle) {
        LOGE("Failed to initialize engine");
        return 0;
    }

    return reinterpret_cast<jlong>(handle);
}

extern "C" JNIEXPORT void JNICALL
Java_com_vidviz_engine_VidvizEnginePlugin_nativeInitJvm(
    JNIEnv* env,
    jobject /* this */
) {
    if (!g_vidvizJvm && env) {
        env->GetJavaVM(&g_vidvizJvm);
    }
}

/**
 * Destroy engine
 */
extern "C" JNIEXPORT void JNICALL
Java_com_vidviz_engine_VidvizEnginePlugin_nativeDestroy(
    JNIEnv* env,
    jobject /* this */,
    jlong handle
) {
    LOGI("Android bridge: nativeDestroy");
    vidviz_engine_destroy(reinterpret_cast<void*>(handle));
}

/**
 * Submit export job
 */
extern "C" JNIEXPORT jint JNICALL
Java_com_vidviz_engine_VidvizEnginePlugin_nativeSubmitJob(
    JNIEnv* env,
    jobject /* this */,
    jlong handle,
    jstring jobJson
) {
    if (!env || !jobJson) return -1;

    const char* jsonStr = env->GetStringUTFChars(jobJson, nullptr);
    if (!jsonStr) return -1;
    
    int result = vidviz_submit_job(
        reinterpret_cast<void*>(handle),
        jsonStr
    );
    
    env->ReleaseStringUTFChars(jobJson, jsonStr);
    return result;
}

/**
 * Cancel job
 */
extern "C" JNIEXPORT void JNICALL
Java_com_vidviz_engine_VidvizEnginePlugin_nativeCancelJob(
    JNIEnv* env,
    jobject /* this */,
    jlong handle
) {
    vidviz_cancel_job(reinterpret_cast<void*>(handle));
}

/**
 * Get status
 */
extern "C" JNIEXPORT jstring JNICALL
Java_com_vidviz_engine_VidvizEnginePlugin_nativeGetStatus(
    JNIEnv* env,
    jobject /* this */,
    jlong handle
) {
    const char* status = vidviz_get_status(reinterpret_cast<void*>(handle));
    if (!status) return nullptr;
    
    jstring result = env->NewStringUTF(status);
    vidviz_free_string(status);
    
    return result;
}

/**
 * Set native window for rendering (Surface → ANativeWindow)
 */
extern "C" JNIEXPORT void JNICALL
Java_com_vidviz_engine_VidvizEnginePlugin_nativeSetSurface(
    JNIEnv* env,
    jobject /* this */,
    jlong handle,
    jobject surface
) {
    if (!surface) {
        LOGW("Surface is null");
        return;
    }
    
    ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
    if (!window) {
        LOGE("Failed to get ANativeWindow from Surface");
        return;
    }
    
    // TODO: Pass window to renderer
    LOGI("Native window set: %p", window);

    // Renderer does not consume the window yet; avoid leaking a reference.
    ANativeWindow_release(window);
}

} // namespace android
} // namespace vidviz
