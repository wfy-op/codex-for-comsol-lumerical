# codex-for-comsol-lumerical

这是一个面向 Codex 的商业仿真求解器连接 skill 仓库。当前版本已经拆成两个独立 skill：`comsol-multiphysics` 负责 COMSOL Multiphysics，`lumerical-fdtd` 负责 Ansys Lumerical FDTD。

它的定位不是某个器件模板，也不是某篇论文或某个光子晶体案例的复现包，而是让 Codex 能够更稳地接管本机求解器的连接说明书、探针脚本和关键语法记忆库。

## 当前结构

`comsol-multiphysics` 保留 COMSOL 命令行、Java API、Python `mph` 会话工具和文档检索能力。它会引导 Codex 先识别操作系统，再从用户给出的路径、环境变量、系统 `PATH` 和常见安装目录里寻找 `comsolbatch`、`comsolcompile` 与可用 Python 环境。仓库中保留的 COMSOL 手册用于本地检索和语法参考。

`lumerical-fdtd` 只面向 Ansys Lumerical FDTD。它会引导 Codex 优先探测 `lumapi` Python API，在 session 或 license 受阻时再退到 `fdtd-solutions` 的 LSF 命令行哨兵脚本。它保留 FDTD 对象创建、监视器、Qanalysis、far-field、sampled material 和失败分类相关语法。

两个 skill 可以单独安装和触发。只做 COMSOL 时用 `comsol-multiphysics`，只做 FDTD 时用 `lumerical-fdtd`，同时需要两边协作时再让 Codex 同时读取两个 skill。

## 安装后怎么和 Codex 聊

安装到 Codex 的 skills 目录后，不需要一上来告诉 Codex 某个固定本机路径。更推荐先把任务说清楚，让 skill 自己带 Codex 走连接探测流程。

比如你可以说：

“用 `comsol-multiphysics` 检查我这台机器上的 COMSOL 能不能被 Codex 调起来，先做 dry run，不要修改任何模型。”

“用 `lumerical-fdtd` 检查 FDTD 的 Python API 和 CLI fallback，失败时帮我分类是 license、session、路径还是语法问题。”

“我有一个 COMSOL `.mph` 文件，帮我只做结果后处理，导出 Q 和 eigenwavelength，不要覆盖原模型。”

“我的 Lumerical Qanalysis 结果没有 `lambda` 字段，帮我按 skill 里的语法改成从 `f` 计算波长。”

如果你已经知道安装目录、license server、Python 环境或模型文件路径，也可以直接告诉 Codex；如果不知道，就让 Codex 先探测。这个仓库的原则是：先找路径，再跑最小探针，再进入真实模型。

## 使用边界

这个仓库刻意不沉淀具体项目的光子晶体结构、PCSEL 参数或器件设计假设。那些内容应该留在项目仓库里，而不是写进通用 skill。

这个仓库也不要求每台机器长得一样。COMSOL 和 Lumerical 的安装位置、license 方式、Python 环境都可能不同，所以 skill 文档和脚本都按“自发现优先、显式路径优先、最小验证优先”的方式组织。

## 适合解决的问题

COMSOL 找不到 `comsolbatch` 或 `comsolcompile`。

COMSOL Java API 能编译但 batch run 没有生成预期文件。

Python `mph` 环境能启动但模型 load、resource 或 tool 调用失败。

Lumerical 的 `lumapi` 能 import 但 `FDTD()` session 启动失败。

FDTD CLI 能运行但 LSF 文件没有写出哨兵结果。

Qanalysis、far-field、sampled material、monitor data 等语法需要按本地版本做最小修复。

## 核心思路

先连接，再验证，再写语法，再跑仿真。

失败时不要马上怀疑模型结构，先判断失败发生在哪一层：路径、环境变量、license、session、脚本语法、结果导出，还是求解器本身。这个 skill 的价值就在于把这些层次拆清楚，让 Codex 少走弯路。
