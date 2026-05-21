# codex-for-comsol-lumerical

这是一个用于连接本机 COMSOL Multiphysics 和 Ansys Lumerical FDTD 的 Codex skill。

它不是 COMSOL 模型模板，也不是 Lumerical FDTD 案例复现包。它更像一份给 Codex 使用的“求解器连接说明书 + 语法记忆库”：帮助 Codex 找到本机求解器，整理 Windows 环境变量，先跑最小探针，再根据已记录的关键语法去写脚本、导出结果、定位失败原因。

## 包含内容

- `SKILL.md`：skill 的主流程，告诉 Codex 什么时候读取哪些参考文件。
- `scripts/probe_comsol.ps1`：COMSOL 路径、版本、Java 编译、batch run 和保存探针。
- `scripts/probe_lumerical.py`：Lumerical `lumapi`、FDTD session 和 CLI LSF 哨兵探针。
- `references/comsol-automation.md`：COMSOL Java API、batch、几何、物理场、网格、Q 值和 table export 语法。
- `references/lumerical-fdtd-automation.md`：Lumerical FDTD `lumapi`、LSF、对象创建、Qanalysis、far-field、数据读取和 sampled material 语法。
- `references/solver-profiles.json`：公开安全的 profile 示例结构，不是任何机器上的已验证配置。

## 安装

把这个仓库安装到 Codex 的 skills 目录中，让 Codex 能识别 `$codex-for-comsol-lumerical`。

安装完成后，在 Codex 对话中直接点名这个 skill 即可使用。

## 操作流程：安装后怎么跟 Codex 聊

使用这个 skill 时，不需要一开始就让 Codex 写完整仿真。更稳的方式是先让它确认求解器连接，再让它写脚本或修复失败。

推荐的对话顺序是：

1. 先说明你要用哪个求解器。

   例如：使用 `$codex-for-comsol-lumerical`，先帮我检查本机 COMSOL 能不能被 Codex 调起来。

   例如：使用 `$codex-for-comsol-lumerical`，先检查本机 Lumerical FDTD 的 `lumapi` 是否能正常启动。

2. 再说明你希望它先做探针，而不是直接跑正式任务。

   例如：先做最小探针，确认路径、环境变量和 license/session 没问题，再继续后面的脚本编写。

   例如：先不要改我的模型，先判断失败发生在连接层、脚本语法层，还是求解器运行层。

3. 探针通过后，再给出具体任务。

   例如：现在用 COMSOL Java API 写一个后处理脚本，加载我的模型，导出一个 result table。

   例如：现在修复我的 Lumerical FDTD 脚本，让它能读取 Qanalysis 的 `Q` 和 `f`，并把波长按 `lambda=c/f` 计算出来。

   例如：现在检查我的 far-field 导出逻辑，确认是 monitor、analysis script、还是数据读取方式出错。

4. 如果任务失败，让 Codex 按最小修复补丁来回答。

   例如：如果失败，请先分类错误，再给我一个 JSON patch，不要一上来重写整个脚本。

   例如：只改最小必要项，比如环境变量、API 路径、命令参数、对象属性名或导出路径。

5. 最后让 Codex 把结论写回你的项目，而不是写进这个 skill。

   例如：把本次求解器连接结果、失败原因和最终修复记录到我当前项目的报告里，不要改 skill 文档。

## 常见对话模板

COMSOL 连接检查：

使用 `$codex-for-comsol-lumerical`，帮我检查本机 COMSOL 自动化是否可用。先做最小探针，确认 `comsolbatch`、`comsolcompile`、Java API 编译和 batch run 是否正常。不要直接修改我的模型。

COMSOL table 导出：

使用 `$codex-for-comsol-lumerical`，读取 COMSOL 参考语法，帮我写一个 Java API 后处理脚本：加载已有模型，选择正确 dataset，导出 EvalGlobal 或 IntVolume 的 table。先说明需要哪一级探针通过。

Lumerical FDTD 连接检查：

使用 `$codex-for-comsol-lumerical`，帮我检查本机 Lumerical FDTD 自动化是否可用。先确认 `lumapi` import、FDTD session 和 license/session 状态，再决定是否使用 CLI LSF fallback。

Lumerical Qanalysis 修复：

使用 `$codex-for-comsol-lumerical`，检查我的 Lumerical FDTD 脚本里 Qanalysis 的创建、运行和读取逻辑。优先读取 `Q` 和 `f`，如果需要波长，用 `lambda=c/f` 计算。失败时给最小 JSON patch。

Lumerical far-field 修复：

使用 `$codex-for-comsol-lumerical`，帮我检查 far-field 相关脚本。先判断 monitor、`farfield3d` 参数、`getv` 变量读取和数据导出哪一层出错，再提出最小修复。

## 使用边界

这个 skill 只覆盖 COMSOL 自动化和 Lumerical FDTD 自动化。

它刻意不包含具体器件设计先验、论文复现流程、项目专用几何模板或材料体系假设。用户当前任务里提供的模型、脚本和几何可以作为输入使用，但不要把它们沉淀回这个通用 skill。

在一台新机器上使用时，不要把示例 profile 当成已验证配置。先让 Codex 跑本机探针，再继续正式仿真或脚本修复。
