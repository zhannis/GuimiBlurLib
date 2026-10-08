# GuimiBlur Binary Distribution

## 1.0.6

CPU 模糊 `radius` 自动限制到 `0..24`，越界不抛异常；CPU 半径与 GPU `sigma` / `blurSigma` 越界时打印 `GuimiBlur` warn，包含原始值与最终采用值。

三个内置 GPU 效果的 `sigma` / `blurSigma` 自动限制到 `0..60`，越界不抛异常；负无穷取 0，正无穷取 60，`NaN` 取 0。

本版本仅允许包名 `com.coocaa.study.jxw`、`com.skyworth.angel.voice`、`com.coocaa.bestiemanager`、`com.tianci.movieplatform` 使用模糊；其他宿主视为不支持模糊，工厂返回普通 View，`supportBlur()` 返回 false，直接创建区域 View 时只显示普通背景，背景 View 保留图片显示但不驱动 CPU 或 GPU 模糊。校验失败不抛异常。包名校验不验证签名，不能防止同包名仿冒或修改 AAR。

`GuimiRegionBlurView` 和 `IWidgetBlurBgView.createBlurView` 的新重载支持 `strokeEnabled` 与 `strokeGradient`，默认保留现有描边；`strokeEnabled = false` 关闭描边，`strokeGradient = null` 使用默认渐变。工厂调用示例：

```kotlin
WidgetBlurHelper.createBlurView(context, roundCorner = 20f, strokeEnabled = false)
WidgetBlurHelper.createBlurView(context, roundCorner = 20f, strokeEnabled = true, strokeGradient = gradient)
```

`com.ccos.guimiblur.WidgetBlurHelper` 是公共入口，Kotlin 使用 `WidgetBlurHelper.createBlurView(...)`，Java 使用 `WidgetBlurHelper.INSTANCE.createBlurView(...)`。先创建 `GuimiHomeBgView` 注册模糊背景源；背景源尚未注册或宿主不在白名单时返回普通 View。

GuimiBlur 的公开二进制发布仓库。只包含混淆后的 Release AAR 和发布配置，不包含库的实现源码、源码包或混淆映射。

| 模块 | 功能 | 最低系统版本 |
| --- | --- | --- |
| `guimi-blur-lib` | CPU 背景模糊、背景 View、区域 View 和扩展接口 | Android 4.4 / API 19 |
| `guimi-blur-ext-lib` | GPU 模糊、液态玻璃、冰块玻璃、自定义 AGSL | Android 14 / API 34 |

两个模块独立发布。只依赖基础库不会引入 GPU 实现；扩展库会通过 POM 自动引入同版本基础库。

## Gradle 接入

在 App 工程的依赖仓库配置中添加：

```groovy
repositories {
    google()
    mavenCentral()
    maven { url 'https://jitpack.io' }
}
```

现代工程放在 `settings.gradle` 的 `dependencyResolutionManagement.repositories` 中；使用旧式配置的工程放在根 `build.gradle` 的 `allprojects.repositories` 或 `subprojects.repositories` 中。不要只放在 `buildscript.repositories`。

只需要 CPU 模糊：

```groovy
implementation 'com.github.zhannis.GuimiBlurLib:guimi-blur-lib:1.0.6'
```

需要 GPU、玻璃或自定义 AGSL：

```groovy
implementation 'com.github.zhannis.GuimiBlurLib:guimi-blur-ext-lib:1.0.6'
```

App 的最低系统版本也需为 API 34。可以显式声明两个依赖，但它们的版本必须一致。依赖信息包含 AndroidX 和 Kotlin，不需要手动复制 AAR 或关闭传递依赖；不建议加 `@aar`，以免跳过依赖元数据。

上述版本需要先推送本仓库的对应 Tag，并在 [JitPack](https://jitpack.io/#com.github.zhannis/GuimiBlurLib/1.0.6) 构建成功才可下载。初始化本地发布工程不代表远程已发布。

## CPU 模糊

背景源放在 item 的下层，各 item 的文字放在模糊区域 View 上层。一个当前背景源可供多个区域按屏幕位置共享取样。

```kotlin
import com.ccos.guimiblur.GuimiBlurConfig
import com.ccos.guimiblur.GuimiCpuBlurEffect
import com.ccos.guimiblur.GuimiHomeBgView
import com.ccos.guimiblur.GuimiRegionBlurView

val source = GuimiHomeBgView(context, needWallpaper = false)
root.addView(source, 0, FrameLayout.LayoutParams(
    ViewGroup.LayoutParams.MATCH_PARENT,
    ViewGroup.LayoutParams.MATCH_PARENT,
))
source.post {
    source.setImageDrawable(ContextCompat.getDrawable(context, R.drawable.page_background))
}

val region = GuimiRegionBlurView(
    context,
    roundCorner = 20f * context.resources.displayMetrics.density,
)
itemContainer.addView(region, 0, FrameLayout.LayoutParams(
    ViewGroup.LayoutParams.MATCH_PARENT,
    ViewGroup.LayoutParams.MATCH_PARENT,
))

GuimiBlurConfig.setCpuEffect(GuimiCpuBlurEffect(
    radius = 6,
    maskColor = 0x22FFFFFF,
))
```

这里的 `root` 和 `itemContainer` 是 `FrameLayout`。`radius` 为 `0..24`，作用于降采样背景；`0` 不模糊。`maskColor` 为 ARGB 叠色。`roundCorner` 单位是像素；椭圆可传 `asOval = true`。不依赖扩展库即可使用 CPU 模式。

## GPU 效果

```kotlin
import com.ccos.guimiblur.ext.*

GuimiBlurExt.install()
GuimiBlurExtConfig.setMode(GuimiBlurMode.GPU)
GuimiBlurExtConfig.setEffect(GuimiBlurEffect(sigma = 18f))
```

安装扩展后默认仍是 CPU，需显式切到 GPU。GPU 要求硬件加速，暂时无法绘制时会回退 CPU。

保留波纹和白色渐变的液态玻璃：

```kotlin
GuimiBlurExtConfig.setEffect(GuimiLiquidGlassEffect(
    refractiveIndex = 1.5f,
    thickness = 1.2f,
    blurSigma = 12f,
))
```

中心通透、边缘有厚边折射的冰块玻璃：

```kotlin
GuimiBlurExtConfig.setEffect(GuimiIceGlassEffect(
    refractiveIndex = 2f,
    thickness = 1.2f,
    blurSigma = 2f,
    refractionHeight = 18f * context.resources.displayMetrics.density,
    chromaticAberration = 0.04f,
    tintColor = 0x00000000,
    highlightStrength = 0.35f,
))
```

| 参数 | 效果 |
| --- | --- |
| `refractiveIndex` | `1..2.5`；越大，边缘折射越明显 |
| `thickness` | `0..8`；视觉厚度倍率，增大后折射位移更强 |
| `blurSigma` | `0..60` 像素；增大后更磨砂，冰块建议从 `0..2` 开始 |
| `refractionHeight` | 冰块专有，`0..200` 像素；向内的折射带宽度，不是位移幅度 |
| `chromaticAberration` | 冰块专有，`0..0.25`；边缘色散，`0` 关闭 |
| `tintColor` | 冰块专有，ARGB；Alpha 控制染色强度，全透明时不染色 |
| `highlightStrength` | 冰块专有，`0..1`；窄边缘高光强度，不控制基础 View 自带描边 |

这些是视觉参数，不是严格物理模拟。冰块玻璃的圆角/椭圆直接沿用区域 View 的形状；水平或垂直越界时按完整 item 计算轮廓。纯色背景不容易看到折射，含纹理的背景更明显。

效果配置不可变。调参或切换效果时创建新 effect，并再次调用 `setEffect(...)`。切回 CPU 用 `setMode(GuimiBlurMode.CPU)`，移除扩展用 `GuimiBlurExt.uninstall()`。

## 自定义 AGSL

```kotlin
val shader = """
    uniform shader content;
    uniform float intensity;

    half4 main(float2 coord) {
        half4 color = content.eval(coord);
        return half4(color.rgb * half(intensity), color.a);
    }
""".trimIndent()

GuimiBlurExtConfig.setEffect(
    GuimiAgslEffect(shader).withFloatUniform("intensity", 0.9f),
)
```

`content` 是库提供的背景输入。还支持 `withIntUniform`、`withColorUniform`；uniform 名称和类型必须与 AGSL 声明匹配。

## 发布维护

本仓库不编译 Android 源码，也不需要 Android SDK。只需 JDK 11 或 17，即可校验并发布已有 AAR。

```powershell
.\gradlew.bat verifyPublications --offline
```

校验包括 AAR SHA-256、公开入口、混淆实现包、授权声明、POM 坐标、传递依赖和发布文件一致性。仅写入本仓库的 `build/verification-repository`，不会向远程上传。

更换二进制、版本 Tag 和 JitPack 发布步骤见 [发布说明](docs/PUBLISHING.md)。JitPack 运行 `publishToMavenLocal` 收集 AAR/POM，不连接私有源码仓库。

## 授权与保密

第三方 MIT 授权声明见 [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt)，也随扩展 AAR 分发；该 MIT 声明仅适用于列出的第三方代码，不代表整个 GuimiBlur 自动采用 MIT 授权。

Gradle Wrapper 的发行授权与 notice 保留在 [gradle/wrapper/LICENSE.txt](gradle/wrapper/LICENSE.txt) 和 [gradle/wrapper/NOTICE.txt](gradle/wrapper/NOTICE.txt)。

不要向本仓库上传源码、Git 私有历史、源码包、`mapping.txt`、密钥或 token。公开 AAR 可被任何人下载和反编译；混淆只能增加阅读成本，不能替代访问控制。
