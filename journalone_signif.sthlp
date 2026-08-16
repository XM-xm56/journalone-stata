{smcl}
{vieweralsosee "JournalOne authorization" "help journalone_license"}{...}
{title:journalone_signif —— 显著组合诊断}

{pstd}该命令提供与“显著组合”窗口对应的可复现规格诊断。它运行基准、稳健性、机制和异质性字段中预先填写的规格；候选控制变量按固定顺序枚举，结果同时保留显著和不显著的估计。{p_end}

{pstd}首次使用可在页面的“密钥”输入栏直接填写发布者提供的授权密钥，也可通过 {help journalone_license} 激活。输入栏使用密码掩码且不记忆，密钥不会写入分析结果或复现文件。{p_end}

{title:语法}
{p 8 12 2}{cmd:journalone_signif, depvar(}{it:y}{cmd:) core(}{it:xlist}{cmd:) [options]}{p_end}

{title:重要边界}
{pstd}本工具不复制只输出显著模型的黑箱筛选，也不会修改数据、自动删除控制变量或反复改变标准误以追求显著。CSV、RTF和DO保留所有预先允许且成功估计的规格；审计文件汇总尝试、成功、失败、数据签名和未自动运行的诊断项。显著性不等于因果识别。{p_end}

{title:主要选项}
{phang}{opt select(reason|grid)} 选择只运行“必留控制”基准规格，或在此基础上枚举候选控制变量组合；两种模式都不按 p 值筛选。其他页面中已填写的稳健性、机制和异质性规格仍按预先登记内容运行。{p_end}
{phang}{opt depvar(name)} 被解释变量；{opt core(varlist)} 核心解释变量；{opt fe(varlist)} 固定效应变量。{p_end}
{phang}{opt vce(string)} 为 {cmd:conventional}、{cmd:robust} 或 {cmd:cluster}；聚类时填写 {opt cluster(name)}。{p_end}
{phang}{opt panel(name)} 面板 ID；{opt time(name)} 时间变量。面板固定/随机效应需要 {opt panel()}；{opt lags()} / {opt leads()} 使用 Stata 的时间序列运算符并要求同时填写 {opt panel()}、{opt time()}。{p_end}
{phang}{opt subsample(string)} 为每条规格附加的 {cmd:if} 条件，例如 {cmd:subsample("year>=2015")}. {p_end}
{phang}{opt keepcontrols(varlist)} 必留控制变量；{opt candidates(varlist)} 候选控制变量。{p_end}
{phang}{opt altx(varlist)}、{opt alty(name)}、{opt addcontrols(varlist)}、{opt addfe(varlist)}、{opt lags(numlist)}、{opt leads(numlist)} 和 {opt altvce(string)} 生成预先登记的稳健性规格。{p_end}
{phang}{opt mediator(varlist)}、{opt moderator(varlist)} 和 {opt group(name)} 分别生成中介、调节和分组交互规格。{p_end}
{phang}{opt policy(string)}、{opt placebo(string)} 和 {opt ptrend} 会写入审计说明，因其需要研究者明确事件窗口/安慰剂设计，当前不会自动生成 p 值。{p_end}
{phang}{opt expectxy(string)}、{opt expectxm(string)}、{opt expectxwy(string)} 记录各路径预期方向；{opt level(real)}、{opt medlevel(real)}、{opt modlevel(real)} 分别用于基准、中介和调节规格的置信区间；{opt mincontrols(integer)} 设定最少控制变量数。{p_end}

{title:输出}
{pstd}默认写入 {cmd:显著组合结果/}：{cmd:显著组合.csv}、{cmd:显著组合.rtf}、{cmd:显著组合.do}、{cmd:显著组合_specifications.dta} 和 {cmd:显著组合_audit.txt}。重复运行会覆盖同名前缀文件。RTF为A4纵向、1.5倍行距和三线表；表格按“规格—变量—估计量”排列，便于核对全部尝试，不是只显示显著模型的横向筛选表。{p_end}

{title:示例}
{p 8 12 2}{cmd:journalone_signif, depvar(y) core(x) fe(industry year) vce(robust) keepcontrols(size age) candidates(lev roa) expectxy(促进)}{p_end}
