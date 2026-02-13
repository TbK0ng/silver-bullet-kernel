# Silver Bullet Kernel 文档中心

这套文档面向两类读者：

- 程序员：需要知道每个命令到底做了什么、为什么这样设计、失败时如何修复。
- 非程序员协作者：需要用清晰步骤看懂“这个流程为什么可靠”。

如果你第一次接触本项目，按下面顺序阅读即可。

## 推荐阅读顺序

1. `docs/01-从Trellis到Silver-Bullet-Kernel的扩展全景.md`
2. `docs/02-功能手册-命令原理与产物.md`
3. `docs/03-实践指南-单人从0到可用性闭环.md`
4. `docs/04-实践指南-双人协作与故障排查.md`
5. `docs/05-命令与产物速查表.md`

## 先记住三个核心原则

1. 产物是唯一真相源：需求、设计、任务、证据都落到仓库文件。
2. 上下文是缓存：会话可以中断，但信息不能只停留在对话里。
3. 执行是可重入状态机：任何步骤失败都要留下证据并可继续推进。

## 10 分钟快速起步

```powershell
npm install
npm run workflow:doctor
npm run verify:fast
npm run memory:context -- -Stage index
npm run metrics:collect
```

你应当看到：

- `workflow:doctor` 通过（或给出明确修复建议）
- `verify:fast` 通过
- `.metrics/` 下生成可追溯报告

## 本套文档和 `xxx_docs` 的关系

- `xxx_docs/`：项目已有的运行文档与操作说明（历史连续性）。
- `docs/`：这次新增的“深度版全景文档”，强调实现原因、治理闭环、逐步实践。

二者不冲突，建议将 `docs/` 作为主学习路径，`xxx_docs/` 作为补充参考。
