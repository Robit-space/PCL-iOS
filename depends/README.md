# depends/

预打包库和资源 - 直接照搬自 [Amethyst-iOS-MyRemastered](https://github.com/herbrine8403/Amethyst-iOS-MyRemastered)

## 目录结构

```
depends/
├── libs/
│   ├── lwjgl/           # LWJGL3 JARs (来自 Amethyst JavaApp/libs/lwjgl)
│   │   ├── lwjgl.jar
│   │   ├── lwjgl-opengl.jar
│   │   ├── lwjgl-openal.jar
│   │   ├── lwjgl-glfw.jar
│   │   ├── lwjgl-stb.jar
│   │   ├── lwjgl-nanovg.jar
│   │   ├── lwjgl-vulkan.jar
│   │   ├── lwjgl-callback-descriptor.jar
│   │   ├── lwjgl-input.jar
│   │   ├── lwjgl-system.jar
│   │   └── lwjgl-util.jar
│   ├── others/          # 其他依赖 (来自 Amethyst JavaApp/libs/others)
│   │   ├── gson-2.13.1.jar
│   │   ├── jsr305.jar
│   │   └── arc_dns_injector.jar
│   ├── caciocavallo/    # Java 8 AWT桥接 (来自 Amethyst JavaApp/libs/caciocavallo)
│   │   ├── ResConfHack.jar
│   │   ├── cacio-androidnw-1.10-SNAPSHOT.jar
│   │   └── cacio-shared-1.10-SNAPSHOT.jar
│   └── caciocavallo17/  # Java 17+ AWT桥接 (来自 Amethyst JavaApp/libs/caciocavallo17)
│       ├── cacio-shared-1.18-SNAPSHOT.jar
│       └── cacio-tta-1.18-SNAPSHOT.jar
└── Frameworks/          # 预编译dylib (来自 Amethyst Natives/resources/Frameworks)
    ├── libMoltenVK.dylib          # MoltenVK 1.4.3 (真机arm64, yitenchen123构建)
    ├── libgl4es_114.dylib         # GL4ES (OpenGL ES 1.1.4 wrapper)
    ├── libOSMesa.8.dylib          # OSMesa (软件渲染)
    ├── libopenal.dylib            # OpenAL音频
    ├── libfreetype.dylib          # FreeType字体
    ├── libglapi.0.dylib           # GL API
    ├── libshaderc.dylib           # ShaderC
    ├── libspirv-cross-c-shared.0.dylib  # SPIRV-Cross
    ├── libvirgl_test_server.dylib # VirGL
    ├── liblwjgl.dylib             # LWJGL native
    ├── liblwjgl_opengl.dylib      # LWJGL OpenGL native
    ├── liblwjgl_nanovg.dylib      # LWJGL NanoVG native
    ├── liblwjgl_stb.dylib         # LWJGL STB native
    ├── liblwjgl_tinyfd.dylib      # LWJGL TinyFD native
    ├── liblwjgl_vma.dylib         # LWJGL VMA native
    ├── AltKit.framework/          # AltStore JIT支持
    ├── CAltKit.framework/         # AltStore JIT支持
    ├── UnzipKit.framework/        # 解压库
    ├── libEGL.framework/          # EGL (MetalANGLE)
    └── libGLESv2.framework/       # GLESv2 (MetalANGLE)
```

## 构建说明

### JRE (Java Runtime)
JRE 需要单独下载 (Azul Zulu for iOS arm64)，参考 Makefile `jre` 目标。

### 自动下载
```bash
make lwjgl    # 下载LWJGL + Caciocavallo JARs
make jre      # 下载Java JRE
make all      # 完整构建
```

### 来源
- LWJGL JARs: `herbrine8403/Amethyst-iOS-MyRemastered` JavaApp/libs/
- Dylibs: `herbrine8403/Amethyst-iOS-MyRemastered` Natives/resources/Frameworks/
- MoltenVK: `yitenchen123/MoltenVK` Actions 构建产物 (1.4.3 真机arm64)
