allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

gradle.projectsEvaluated {
    rootProject.subprojects
        .find { it.name == "audio_service" }
        ?.let { audioService ->
            patchMediaPlaybackForeground(
                audioService.file(
                    "src/main/java/com/ryanheise/audioservice/AudioService.java",
                ),
            )
        }
}

// audio_service 0.18.19 appelle startForeground sans type. A partir
// d'Android 14, le service de lecture doit declarer mediaPlayback
// au moment du demarrage, sinon le systeme l'arrete.
fun patchMediaPlaybackForeground(javaFile: java.io.File) {
    if (!javaFile.exists()) return
    var source = javaFile.readText()
    val needle = "startForeground(NOTIFICATION_ID, buildNotification());"
    if (!source.contains("FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK") && source.contains(needle)) {
        val replacement =
            """
            if (android.os.Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, buildNotification(), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
            } else {
                startForeground(NOTIFICATION_ID, buildNotification());
            }
            """.trimIndent()
        source = source.replace(needle, replacement)
    }
    val silentChannel =
        "new NotificationChannel(notificationChannelId, config.androidNotificationChannelName, NotificationManager.IMPORTANCE_LOW);"
    if (source.contains(silentChannel)) {
        source =
            source.replace(
                silentChannel,
                """
                new NotificationChannel(notificationChannelId, config.androidNotificationChannelName, NotificationManager.IMPORTANCE_DEFAULT);
            channel.setSound(null, null);
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
                """.trimIndent(),
            )
    }
    javaFile.writeText(source)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
