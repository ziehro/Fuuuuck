# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }

# Google ML Kit / TFLite GPU
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.GpuDelegate

# Keep all TensorFlow classes from being obfuscated
-keep class org.tensorflow.** { *; }