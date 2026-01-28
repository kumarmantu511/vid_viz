package com.vidviz.engine

import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin

class VidvizEnginePlugin: FlutterPlugin {

    // 1. C++ Kütüphanesini Yükle
    companion object {
        private const val TAG = "VidvizEnginePlugin"

        init {
            try {
                System.loadLibrary("vidviz_engine") // CMakeLists.txt içindeki library ismin
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Native kütüphane yüklenemedi", e)
            }
        }

        // Native fonksiyon tanımı
        @JvmStatic external fun nativeInitJvm()
    }

    // 2. Flutter motoru paketi görünce otomatik çalıştırır
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        try {
            nativeInitJvm()
            Log.i(TAG, "Vidviz Engine (Plugin) başarıyla başlatıldı.")
        } catch (e: Throwable) {
            Log.e(TAG, "Vidviz Engine başlatılamadı", e)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        // Gerekirse temizlik
    }
}