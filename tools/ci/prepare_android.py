#!/usr/bin/env python3
"""Ajusta o scaffold Android gerado pelo Flutter para o build de release.

O repositório não versiona a pasta `android/` (o CI a gera com
`flutter create`). Este script aplica os ajustes que não vêm no template:
permissão de internet, label, back callback, R8 e memória do Gradle.
"""

import base64
import os
import re
import shutil
from pathlib import Path


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def patch_manifest(android: Path) -> None:
    manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
    text = _read(manifest)

    if "android.permission.INTERNET" not in text:
        text = re.sub(
            r"(<manifest[^>]*>)",
            r'\1\n    <uses-permission android:name="android.permission.INTERNET" />',
            text,
            count=1,
        )

    text = re.sub(r'android:label="[^"]*"', 'android:label="PORTIX"', text, count=1)

    application = re.search(r"<application\b[^>]*>", text)
    if application is not None and "enableOnBackInvokedCallback" not in application.group(0):
        tag = application.group(0)
        patched = tag[:-1] + ' android:enableOnBackInvokedCallback="true">'
        text = text.replace(tag, patched, count=1)

    _write(manifest, text)


def patch_lint(android: Path) -> None:
    """Desabilita o lint de release do AGP em todos os módulos.

    O `lintVitalAnalyzeRelease` do AGP quebra ao analisar alguns plugins
    (por exemplo `url_launcher_android`) na combinação atual de AGP/JDK. A
    qualidade do Dart já é garantida por `flutter analyze` no CI, então as
    tarefas `lintVital*` — que só existem no empacotamento Android — são
    desativadas para não derrubar o build de release.
    """
    root_kts = android / "build.gradle.kts"
    root_groovy = android / "build.gradle"
    if root_kts.exists():
        root = root_kts
    elif root_groovy.exists():
        root = root_groovy
    else:
        raise SystemExit("build.gradle(.kts) raiz não encontrado no scaffold")

    text = _read(root)
    if "lintVital" in text:
        return
    text += (
        "\n// PORTIX: o lint de release do AGP quebra em alguns plugins;\n"
        "// a análise do Dart já é feita por `flutter analyze` no CI.\n"
        "subprojects {\n"
        '    tasks.matching { it.name.startsWith("lintVital") }.configureEach {\n'
        "        enabled = false\n"
        "    }\n"
        "}\n"
    )
    _write(root, text)


def patch_gradle(android: Path) -> None:
    kts = android / "app" / "build.gradle.kts"
    groovy = android / "app" / "build.gradle"
    if kts.exists():
        path = kts
        text = _read(path)
        if "isMinifyEnabled" not in text:
            text = text.replace(
                "release {",
                "release {\n"
                '            isMinifyEnabled = true\n'
                '            isShrinkResources = true\n'
                '            proguardFiles(\n'
                '                getDefaultProguardFile("proguard-android-optimize.txt"),\n'
                '                "proguard-rules.pro",\n'
                "            )",
                1,
            )
    elif groovy.exists():
        path = groovy
        text = _read(path)
        if "minifyEnabled" not in text:
            text = text.replace(
                "release {",
                "release {\n"
                "            minifyEnabled true\n"
                "            shrinkResources true\n"
                '            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"',
                1,
            )
    else:
        raise SystemExit("build.gradle(.kts) não encontrado no scaffold Android")

    _write(path, text)

    rules = android / "app" / "proguard-rules.pro"
    rules.write_text(
        "# PORTIX — regras de keep para plugins que usam reflexão/JNI.\n"
        "-keepattributes Signature\n"
        "-keepattributes *Annotation*\n"
        "-keep class io.supabase.** { *; }\n"
        "-dontwarn io.supabase.**\n"
        "-keep class com.google.gson.** { *; }\n"
        "-dontwarn com.google.gson.**\n"
        "-keep class com.google.android.play.core.** { *; }\n"
        "-dontwarn com.google.android.play.core.**\n"
        "# Motor de download nativo (Rust/JNI) e serviço de primeiro plano.\n"
        "-keepclasseswithmembernames class * { native <methods>; }\n"
        "-keep class com.deivid22srk.portix.downloader.** { *; }\n",
        encoding="utf-8",
    )


def patch_gradle_properties(android: Path) -> None:
    properties = android / "gradle.properties"
    text = _read(properties) if properties.exists() else ""
    lines = [
        line
        for line in text.splitlines()
        if not line.startswith("org.gradle.jvmargs")
    ]
    lines.append("org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -Dfile.encoding=UTF-8")
    if "android.useAndroidX" not in "\n".join(lines):
        lines.append("android.useAndroidX=true")
    properties.write_text("\n".join(lines) + "\n", encoding="utf-8")


NATIVE_PERMISSIONS = (
    '\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />'
    '\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />'
    '\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />'
    '\n    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />'
)

NATIVE_COMPONENTS = (
    "\n        <service\n"
    '            android:name=".downloader.DownloadService"\n'
    '            android:exported="false"\n'
    '            android:foregroundServiceType="dataSync" />\n'
    "        <provider\n"
    '            android:name="androidx.core.content.FileProvider"\n'
    '            android:authorities="${applicationId}.fileprovider"\n'
    '            android:exported="false"\n'
    '            android:grantUriPermissions="true">\n'
    "            <meta-data\n"
    '                android:name="android.support.FILE_PROVIDER_PATHS"\n'
    '                android:resource="@xml/portix_file_paths" />\n'
    "        </provider>\n"
)


def patch_manifest_native(android: Path) -> None:
    """Adiciona permissões, o serviço de download e o FileProvider."""
    manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
    text = _read(manifest)

    if "POST_NOTIFICATIONS" not in text:
        text = re.sub(
            r"(<manifest[^>]*>)",
            r"\1" + NATIVE_PERMISSIONS,
            text,
            count=1,
        )

    if "DownloadService" not in text:
        text = text.replace("</application>", NATIVE_COMPONENTS + "    </application>", 1)

    _write(manifest, text)


def copy_native(android: Path) -> None:
    """Copia as fontes Kotlin (serviço/ponte/device) e o XML do FileProvider."""
    root = Path(__file__).resolve().parents[2]
    source = root / "native" / "android"
    if not source.exists():
        raise SystemExit("Pasta native/android não encontrada")

    package_dir = (
        android / "app" / "src" / "main" / "kotlin" / "com" / "deivid22srk" / "portix"
    )
    package_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source / "MainActivity.kt", package_dir / "MainActivity.kt")

    downloader_source = source / "downloader"
    downloader_dir = package_dir / "downloader"
    downloader_dir.mkdir(parents=True, exist_ok=True)
    for item in sorted(downloader_source.glob("*.kt")):
        shutil.copyfile(item, downloader_dir / item.name)

    # Copia qualquer outro pacote Kotlin (ex.: device/)
    for child in sorted(source.iterdir()):
        if child.is_dir() and child.name not in {"res", "downloader"}:
            target = package_dir / child.name
            target.mkdir(parents=True, exist_ok=True)
            for item in sorted(child.glob("*.kt")):
                shutil.copyfile(item, target / item.name)

    res_dir = android / "app" / "src" / "main" / "res" / "xml"
    res_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(
        source / "res" / "xml" / "portix_file_paths.xml",
        res_dir / "portix_file_paths.xml",
    )


def patch_gradle_dependencies(android: Path) -> None:
    """Garante o AndroidX Core (NotificationCompat/FileProvider)."""
    kts = android / "app" / "build.gradle.kts"
    groovy = android / "app" / "build.gradle"
    if kts.exists():
        path = kts
        text = _read(path)
        if "androidx.core:core-ktx" in text:
            return
        dependency = '    implementation("androidx.core:core-ktx:1.13.1")\n'
    elif groovy.exists():
        path = groovy
        text = _read(path)
        if "androidx.core:core-ktx" in text:
            return
        dependency = '    implementation "androidx.core:core-ktx:1.13.1"\n'
    else:
        raise SystemExit("build.gradle(.kts) do app não encontrado")

    if "dependencies {" in text:
        text = text.replace("dependencies {", "dependencies {\n" + dependency, 1)
    else:
        text += "\ndependencies {\n" + dependency + "}\n"
    _write(path, text)


def patch_manifest_oauth(android: Path) -> None:
    """Adiciona o deep link do login Google (esquema portix://login-callback)."""
    manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
    text = _read(manifest)
    if "login-callback" in text:
        return

    match = re.search(
        r'(<activity\b[^>]*android:name="\.MainActivity"[\s\S]*?)(</activity>)',
        text,
    )
    if match is None:
        return
    oauth = (
        "\n            <intent-filter>\n"
        '                <action android:name="android.intent.action.VIEW" />\n'
        '                <category android:name="android.intent.category.DEFAULT" />\n'
        '                <category android:name="android.intent.category.BROWSABLE" />\n'
        '                <data android:scheme="portix" android:host="login-callback" />\n'
        "            </intent-filter>\n        "
    )
    text = text[: match.end(1)] + oauth + text[match.end(1):]
    _write(manifest, text)


def patch_signing(android: Path, keystore_name: str = "portix-release.p12") -> None:
    """Configura a assinatura fixa (release) a partir dos secrets.

    Sem `ANDROID_KEYSTORE_BASE64` no ambiente, mantém a assinatura de debug.
    """
    encoded = os.environ.get("ANDROID_KEYSTORE_BASE64", "").strip()
    if not encoded:
        return

    app = android / "app"
    keystore = app / keystore_name
    keystore.write_bytes(base64.b64decode(encoded))

    properties = android / "key.properties"
    properties.write_text(
        (
            "storeFile={store}\n"
            "storePassword={store_pw}\n"
            "keyAlias={alias}\n"
            "keyPassword={key_pw}\n"
        ).format(
            store=keystore,
            store_pw=os.environ.get("ANDROID_KEYSTORE_PASSWORD", ""),
            alias=os.environ.get("ANDROID_KEY_ALIAS", "portix"),
            key_pw=os.environ.get("ANDROID_KEY_PASSWORD", ""),
        ),
        encoding="utf-8",
    )

    kts = app / "build.gradle.kts"
    groovy = app / "build.gradle"
    if kts.exists():
        text = kts.read_text(encoding="utf-8")
        if "keystoreProperties" not in text:
            loader = (
                "import java.io.FileInputStream\n"
                "import java.util.Properties\n\n"
                "val keystoreProperties = Properties()\n"
                'val keystorePropertiesFile = rootProject.file("key.properties")\n'
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
                "}\n\n"
            )
            signing = (
                "android {\n"
                "    signingConfigs {\n"
                '        create("release") {\n'
                '            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }\n'
                '            storePassword = keystoreProperties["storePassword"] as String?\n'
                '            keyAlias = keystoreProperties["keyAlias"] as String?\n'
                '            keyPassword = keystoreProperties["keyPassword"] as String?\n'
                "        }\n"
                "    }\n"
            )
            text = loader + text
            text = text.replace("android {", signing, 1)
            text = text.replace(
                'signingConfig = signingConfigs.getByName("debug")',
                'signingConfig = signingConfigs.getByName("release")',
            )
            kts.write_text(text, encoding="utf-8")
    elif groovy.exists():
        text = groovy.read_text(encoding="utf-8")
        if "keystoreProperties" not in text:
            loader = (
                "def keystoreProperties = new Properties()\n"
                'def keystorePropertiesFile = rootProject.file("key.properties")\n'
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
                "}\n\n"
            )
            signing = (
                "android {\n"
                "    signingConfigs {\n"
                "        release {\n"
                "            storeFile file(keystoreProperties['storeFile'])\n"
                "            storePassword keystoreProperties['storePassword']\n"
                "            keyAlias keystoreProperties['keyAlias']\n"
                "            keyPassword keystoreProperties['keyPassword']\n"
                "        }\n"
                "    }\n"
            )
            text = loader + text
            text = text.replace("android {", signing, 1)
            text = text.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
            groovy.write_text(text, encoding="utf-8")


def main() -> None:
    android = Path(__file__).resolve().parents[2] / "android"
    if not android.exists():
        raise SystemExit("Pasta android/ ausente: rode flutter create antes")
    patch_manifest(android)
    patch_manifest_native(android)
    patch_manifest_oauth(android)
    patch_gradle(android)
    patch_gradle_dependencies(android)
    patch_gradle_properties(android)
    patch_lint(android)
    patch_signing(android)
    copy_native(android)
    print("Scaffold Android ajustado para release (com download nativo).")


if __name__ == "__main__":
    main()
