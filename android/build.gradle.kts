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

// Force all plugin subprojects to compile against SDK 36 — some plugins
// (e.g. agora_rtc_engine) require SDK 34+, but older plugin build.gradle
// files default to lower versions.
// Also fix missing namespace for older plugins (required by AGP 8.x).
subprojects {
    afterEvaluate {
        val android = project.extensions.findByName("android") ?: return@afterEvaluate
        try {
            val prop = android.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
            prop.invoke(android, 36)
        } catch (_: Exception) {
            try {
                val prop = android.javaClass.getMethod("setCompileSdk", Integer::class.java)
                prop.invoke(android, 36)
            } catch (_: Exception) {}
        }

        // Fix missing namespace — extract from AndroidManifest.xml package attribute
        try {
            val nsField = android.javaClass.getMethod("getNamespace")
            val currentNs = nsField.invoke(android)
            if (currentNs == null) {
                val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestText = manifestFile.readText()
                    val pkgMatch = Regex("""package="([^"]+)""").find(manifestText)
                    if (pkgMatch != null) {
                        val pkg = pkgMatch.groupValues[1]
                        val setNs = android.javaClass.getMethod("setNamespace", String::class.java)
                        setNs.invoke(android, pkg)
                        println("Set namespace for ${project.name}: $pkg")
                    }
                }
            }
        } catch (_: Exception) {}

        // Force Java/Kotlin 21 for all plugin subprojects to avoid JVM-target
        // incompatibilities between Java and Kotlin compile tasks.
        try {
            val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
            val setSource = compileOptions.javaClass.methods.find {
                it.name == "setSourceCompatibility" && it.parameterCount == 1
            }
            val setTarget = compileOptions.javaClass.methods.find {
                it.name == "setTargetCompatibility" && it.parameterCount == 1
            }
            try {
                setSource?.invoke(compileOptions, JavaVersion.VERSION_21)
                setTarget?.invoke(compileOptions, JavaVersion.VERSION_21)
            } catch (_: Exception) {
                setSource?.invoke(compileOptions, "21")
                setTarget?.invoke(compileOptions, "21")
            }
        } catch (_: Exception) {}

        // Reflectively force Kotlin jvmTarget = 21 on all Kotlin compile tasks.
        tasks.configureEach {
            val taskClassName = javaClass.name
            if ("KotlinCompile" in taskClassName) {
                try {
                    val kotlinOptions = javaClass.getMethod("getKotlinOptions").invoke(this)
                    kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
                        .invoke(kotlinOptions, "21")
                } catch (_: Exception) {}
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
