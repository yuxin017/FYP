# MediaPipe's Flogger backend walks its own call stack. Keep its caller lookup
# and backend methods intact so release optimization does not change the stack.
-keep class com.google.common.flogger.** { *; }

# MediaPipe's native code uses these packet fields, factories and callbacks.
-keep class com.google.mediapipe.framework.ProtoUtil$SerializedMessage {
    public java.lang.String typeName;
    public byte[] value;
}
-keep class com.google.mediapipe.framework.Packet { *; }
-keep interface com.google.mediapipe.framework.Packet*Callback { *; }
-keepclassmembers class * implements com.google.mediapipe.framework.Packet*Callback {
    public void process(...);
}
-keep class com.google.mediapipe.framework.MediaPipeException {
    <init>(int, byte[]);
}

# The detector's task options use Any and Protobuf Lite looks up its fields by name.
-keep class com.google.protobuf.Any {
    <fields>;
}
