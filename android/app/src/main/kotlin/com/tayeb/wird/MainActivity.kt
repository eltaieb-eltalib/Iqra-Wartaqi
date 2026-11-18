package com.tayeb.wird

import com.ryanheise.audioservice.AudioServiceActivity

// يجب أن تطابق الحزمة namespace في build.gradle.kts (com.tayeb.wird)
// لأن المانيفست يشير إلى ".MainActivity"، وإلا يتعطل التطبيق عند الفتح.
// ويجب أن يرث AudioServiceActivity لكي تعمل حزمة audio_service.
class MainActivity : AudioServiceActivity()
