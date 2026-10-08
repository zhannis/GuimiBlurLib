# 发布说明

## 仓库边界

私有仓库负责编译和混淆。这里负责将已有 AAR 发布为 Maven 依赖，不包含 Android 插件、实现源码或私有仓库凭据。远程地址是 `https://github.com/zhannis/GuimiBlurLib`。

```text
GitGuimiBlurLib/
  aars/
    GuimiBlurLib-release.aar
    GuimiBlurExtLib-release.aar
  guimi-blur-lib/build.gradle
  guimi-blur-ext-lib/build.gradle
  gradle/binary-publish.gradle
  gradle/wrapper/
  scripts/Update-Aars.ps1
  artifacts.json
  build.gradle
  settings.gradle
  gradle.properties
  jitpack.yml
  gradlew
  gradlew.bat
  README.md
  THIRD_PARTY_NOTICES.txt
```

## 更新 AAR

1. 在私有源码工程生成并验证两个同批次的混淆 Release AAR。不要拿 debug AAR 发布，不要让基础库和扩展库来自不同兼容版本。
2. 在本仓库运行导入脚本，输入目录必须同时包含两个 `*-release.aar`：

```powershell
.\scripts\Update-Aars.ps1 -SourceDirectory 'D:\path\to\private-project\GuimiBlurDemo\libs'
```

脚本只复制两个确定的文件，并更新 `artifacts.json` 中的 SHA-256，不会复制源码、私有 Git 历史、其他构建产物或凭据。然后运行发布校验：

```powershell
.\gradlew.bat verifyPublications --offline
```

离线命令要求 Gradle 7.3.3 已在本机缓存。未缓存时去掉 `--offline`，Wrapper 会下载 Gradle。

## 设置版本和发布

当前本地默认 `releaseVersion=1.0.3`，初始 AAR 来自现有已构建的 Release 文件，尚未在本 GitHub 公有仓库创建 Tag 或远程发布。

1. 修改 `gradle.properties` 的 `releaseVersion`，并同步 README 的版本示例。
2. 若私有源码工程的外部依赖发生变化，同步两个模块 `build.gradle` 的 `pomDependencies`。原始 AAR 本身没有 Maven 传递依赖信息，不能只替换 AAR 而忽略这一项。
3. 再次运行 `verifyPublications`，检查生成的两个 POM。扩展 POM 必须依赖本公有发布坐标下的同版本基础库，不能指向私有仓库。
4. 检查 `git status`、`git diff` 和提交内容；确认只有允许公开的二进制、脚本和文档。
5. 提交、推送，然后创建并推送相同版本的 Tag。例如首个版本：

```powershell
git add .
git commit -m "Publish GuimiBlur binary 1.0.3"
git push origin main
git tag 1.0.3
git push origin 1.0.3
```

示例沿用当前本地 `main` 分支；远程分支不同需相应调整。不要移动已发布的 Tag，每次替换 AAR 建议发布新版本。

6. 在 [JitPack](https://jitpack.io/#com.github.zhannis/GuimiBlurLib) 查找此公有仓库，选择 Tag 并点击 Get it。构建成功后检查两个模块，而不是仅看仓库聚合依赖。

JitPack 通过 `jitpack.yml` 选择 JDK 17，并运行：

```sh
bash ./gradlew --no-daemon verifyPublications publishToMavenLocal
```

版本优先使用 JitPack 的 `VERSION` 环境变量，因此发布版本与请求的 Tag/提交一致。模块 group 使用 JitPack 的 `GROUP` 和 `ARTIFACT` 拼接，未提供时使用 `com.github.zhannis.GuimiBlurLib`。没有编译、访问私有源码或远程 Maven 上传步骤，JitPack 会收集本地 Maven 仓库里的 AAR/POM。

如果日志出现 `JAVA_HOME is set to an invalid directory: /usr/lib/jvm/jdk-11`，说明 Gradle 尚未启动，需确认构建的提交包含选择 `openjdk17` 的 `jitpack.yml`。只推送分支不会改变旧 Tag 指向的提交；可创建新版本 Tag 后构建，并将接入依赖的版本改为该 Tag 的完整名称（`1.0.1` 与 `1.0.3` 是不同版本）。

## 本地验证

```powershell
.\gradlew.bat verifyPublications --offline
.\gradlew.bat verifyPublications -PpublishVersion=v1.0.3 --offline
```

产物在 `build/verification-repository/com/github/zhannis/GuimiBlurLib/<module>/<version>/`，不进入 Git。检查 POM 的 `<packaging>aar</packaging>`、依赖版本和发布后 AAR 的 SHA-256。

若需要检查与 JitPack 一样的收集方式，可运行 `publishToMavenLocal`；它会写入用户的 Maven 本地仓库，但不会上传到远程。正常本地验证使用 `verifyPublications` 即可。

## App 坐标

```groovy
implementation 'com.github.zhannis.GuimiBlurLib:guimi-blur-lib:1.0.3'
implementation 'com.github.zhannis.GuimiBlurLib:guimi-blur-ext-lib:1.0.3'
```

CPU-only App 仅保留第一项；GPU App 可以只声明第二项，它会传递引入基础库。不要引用旧私有仓库坐标，也不要用聚合坐标给 CPU-only App 引入整个仓库。

如果更换远程用户名或仓库名，修改 `repositoryOwner` / `repositoryName` 和文档中的坐标/链接。JitPack 上的实际坐标最终由新的远程地址决定。

## 安全检查

- 不上传 `src`、源码包、混淆映射、签名文件、token、`local.properties`、IDE 或缓存目录。
- `.gitignore` 限制常见敏感文件，但不是安全扫描器；每次提交仍需检查暂存区内容。
- 不把整个私有源码仓库推送到这个公有仓库，包括历史提交。
- 第三方授权声明应保留在扩展 AAR 中；上游 notice 变化时同步根目录副本。
- SHA-256 校验用于防止二进制与清单不一致，不证明源码安全，也不能阻止反编译。

## 参考

- [JitPack 已有 AAR 发布](https://docs.jitpack.io/faq/#can-i-publish-an-existing-jar-or-aar-file)
- [JitPack 多模块坐标](https://docs.jitpack.io/building/#multi-module-projects)
- [JitPack 自定义发布命令](https://docs.jitpack.io/building/#custom-commands)
