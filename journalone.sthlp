{smcl}
{* *! version 0.9.22 06sep2026}{...}
{vieweralsosee "JournalOne authorization" "help journalone_license"}{...}
{vieweralsosee "JournalOne one-click update" "help journalone_update"}{...}
{vieweralsosee "JournalOne preprocessing" "help journalone_prep"}{...}
{vieweralsosee "regress" "help regress"}{...}
{vieweralsosee "xtreg" "help xtreg"}{...}
{vieweralsosee "ivregress" "help ivregress"}{...}
{vieweralsosee "pwcorr" "help pwcorr"}{...}
{vieweralsosee "estat vif" "help regress postestimation"}{...}
{vieweralsosee "xttest0" "help xtreg postestimation"}{...}
{vieweralsosee "hausman" "help hausman"}{...}
{vieweralsosee "teffects psmatch" "help teffects psmatch"}{...}
{vieweralsosee "heckman" "help heckman"}{...}
{vieweralsosee "xtabond" "help xtabond"}{...}
{vieweralsosee "xporegress" "help xporegress"}{...}

{title:Title}

{p 4 8 2}{cmd:journalone} — 期刊实证分析原生 Stata 图形插件{p_end}

{pstd}JournalOne 是变量名与研究主题无关的通用实证工作流。被解释变量、核心变量、控制变量、处理组、固定效应、工具变量、匹配协变量和权重均由使用者指定；帮助中的变量名只用于展示语法。仓库中的具体数据仅作为回归测试。插件覆盖常见模块，但不会用统一按钮替代尚未实现的方法或研究设计判断。{p_end}

{title:Open the GUI}

{p 8 12 2}{cmd:. journalone}{p_end}
{p 8 12 2}{cmd:. db journalone}{p_end}

{title:Syntax}

{p 8 12 2}
{cmd:journalone,}
[{opt model(string)}
{opt depvar(varname)}
{opt indepvars(varlist)}
{opt controls(varlist)}
{opt panel(varname)}
{opt time(varname)}
{opt absorb(string)}
{opt timefe}
{opt vcetype(string)}
{opt cluster(string)}
{opt model2(string)}
{opt depvar2(varname)}
{opt indepvars2(varlist)}
{opt controls2(varlist)}
{opt panel2(varname)}
{opt time2(varname)}
{opt absorb2(string)}
{opt timefe2}
{opt vcetype2(string)}
{opt cluster2(string)}
{opt ifcond2(expression)}
{opt model3(string)}
{opt depvar3(varname)}
{opt indepvars3(varlist)}
{opt controls3(varlist)}
{opt panel3(varname)}
{opt time3(varname)}
{opt absorb3(string)}
{opt timefe3}
{opt vcetype3(string)}
{opt cluster3(string)}
{opt ifcond3(expression)}
{opt model4(string)}
{opt depvar4(varname)}
{opt indepvars4(varlist)}
{opt controls4(varlist)}
{opt panel4(varname)}
{opt time4(varname)}
{opt absorb4(string)}
{opt timefe4}
{opt vcetype4(string)}
{opt cluster4(string)}
{opt ifcond4(expression)}
{opt model5(string)}
{opt depvar5(varname)}
{opt indepvars5(varlist)}
{opt controls5(varlist)}
{opt panel5(varname)}
{opt time5(varname)}
{opt absorb5(string)}
{opt timefe5}
{opt vcetype5(string)}
{opt cluster5(string)}
{opt ifcond5(expression)}
{opt model6(string)}
{opt depvar6(varname)}
{opt indepvars6(varlist)}
{opt controls6(varlist)}
{opt panel6(varname)}
{opt time6(varname)}
{opt absorb6(string)}
{opt timefe6}
{opt vcetype6(string)}
{opt cluster6(string)}
{opt ifcond6(expression)}
{opt treat(varname)}
{opt post(varname)}
{opt endog(varlist)}
{opt instruments(varlist)}
{opt ifcond(expression)}
{opt descvars(varlist)}
{opt nodesc}
{opt corrvars(varlist)}
{opt vifcheck}
{opt paneltests}
{opt ivtests}
{opt ovbtest}
{opt descsample(string)}
{opt alty(varlist)}
{opt altx(varlist)}
{opt customspecs(string)}
{opt addcontrols(varlist)}
{opt addfe(string)}
{opt lags(numlist)}
{opt leads(numlist)}
{opt subsample(expression)}
{opt altvce(string)}
{opt altcluster(string)}
{opt mediators(varlist)}
{opt medclusters(string)}
{opt moderators(varlist)}
{opt modinteractions(string)}
{opt group(varname)}
{opt ptrend}
{opt ptlevel(#)}
{opt ptbase(#)}
{opt psmmethod(string)}
{opt psmcovars(varlist)}
{opt psmtime(varname)}
{opt psmneighbor(#)}
{opt psmweight(varname)}
{opt heckmansel(varname)}
{opt heckmancovars(varlist)}
{opt heckmanfe}
{opt gmmmethod(string)}
{opt gmmextra(varlist)}
{opt gmmlags(#)}
{opt gmmtwostep}
{opt dmlmethod(string)}
{opt dmlinstruments(varlist)}
{opt dmlcontrols(varlist)}
{opt dmlfolds(#)}
{opt reps(#)}
{opt groupbins(#)}
{opt grouptest}
{opt splithet}
{opt medmethod(string)}
{opt splitmed}
{opt modplot}
{opt adjustmethod(string)}
{opt winsorlow(#)}
{opt winsorhigh(#)}
{opt reportmode(string)}
{opt decimals(#)}
{opt statistic(string)}
{opt missingmode(string)}
{opt keepsingletons}
{opt pstar1(#)}
{opt pstar2(#)}
{opt pstar3(#)}
{opt outdir(path)}
{opt prefix(name)}
{opt level(#)}
{opt seed(#)}
{opt replace}]

{title:Independent and combined modules}

{phang}{bf:仅描述性统计：}省略 {opt depvar()}，并明确填写 {opt descvars()}。“描述性统计分析结果”文件夹只保留 RTF/DO/CSV 三件套；运行日志和发布中间文件均不留在输出根目录。{p_end}

{phang}{bf:仅基准回归：}填写 {opt depvar()} 及模型所需变量，并指定 {opt nodesc}。图形界面在描述性统计未勾选且统计变量留空时自动生成 {opt nodesc}。{p_end}

{phang}{bf:组合运行：}同时填写回归字段和 {opt descvars()}，或在有基准回归时勾选描述性统计。后一种情况下，若 {opt descvars()} 留空，程序按变量角色自动选择并排序。{p_end}

{phang}{bf:仅相关性分析：}省略 {opt depvar()}，填写 {opt corrvars()}。相关性、VIF、面板模型检验和IV第一阶段诊断也可与其他模块组合；后三项依赖模型1的变量和结构设定。{p_end}

{phang}{bf:扩展模块：}稳健性、内生性、机制和异质性字段留空即跳过，填写后与基准模型组合运行。依赖回归变量的检验仍要求必要的 {opt depvar()}、核心变量和识别变量。所有模块均为空时返回 {cmd:r(198)}，不生成空表。{p_end}

{title:Supported main models}

{synoptset 18 tabbed}{...}
{synopthdr:model()}
{synoptline}
{synopt:{cmd:ols}}普通最小二乘回归{p_end}
{synopt:{cmd:hdfe}}高维固定效应，调用 {cmd:reghdfe}；固定效应填写在 {cmd:absorb()}{p_end}
{synopt:{cmd:fe}}面板固定效应；必须指定 {cmd:panel()} 和 {cmd:time()}{p_end}
{synopt:{cmd:re}}面板随机效应；必须指定 {cmd:panel()} 和 {cmd:time()}{p_end}
{synopt:{cmd:did}}共同政策时点的简单 2x2 DID，并加入单位和时间固定效应{p_end}
{synopt:{cmd:iv}}官方 {cmd:ivregress 2sls} 两阶段最小二乘{p_end}
{synoptline}

{title:Main page: seven empirical modules}

{phang}{bf:描述性统计：}{opt descvars()} 严格保留输入顺序。留空时，JournalOne 按被解释变量、核心/内生/DID变量、控制变量、工具变量、中介/调节变量和分组变量自动排序。输出 N、缺失数、均值、标准差、最小值和最大值，以及 {cmd:variable_order}、{cmd:variable_role}。{opt descsample(main)} 使用基准估计样本；{opt descsample(full)} 使用满足 {opt ifcond()} 的全样本。{opt nodesc} 关闭此模块。{p_end}

{phang}{bf:基准回归：}基准回归直接在“实证分析”主页面内展开或收起，不创建单独页签或新窗口。窗口打开时先显示模块总览，点击“展开基准回归”后隐藏置信水平和其他实证模块，仅保留基准回归编辑区；编辑框高度随已配置组数自动调整。该区域支持 1—6 组 OLS、HDFE、面板 FE/RE、简单 DID 或 2SLS-IV。每点击一次“＋ 添加下一组”只按模型 1 → 2 → 3 → 4 → 5 → 6 增加下一组，新模型会直接完整显示；“－ 删除最后一组”按相反顺序逐组删除。模型 1—6 采用相同的五行固定栅格，标签列和输入列分别对齐，不设置子模型折叠按钮。模型 2—6 分别使用同序号的 {opt model2()}—{opt model6()}、{opt depvar2()}—{opt depvar6()} 等选项，必须连续填写。{opt vcetype()} 可为 {cmd:conventional}、{cmd:robust} 或 {cmd:cluster}；聚类时必须填写相应的 {opt cluster()}。模型 1 是后续稳健性、内生性、机制和异质性模块的主模型。{p_end}

{phang}{bf:稳健性检验：}{opt alty()}、{opt altx()}、{opt addcontrols()}、{opt addfe()}、{opt subsample()}、{opt lags()}、{opt leads()} 和 {opt altvce()} 运行预先设定的替代规格。{opt customspecs()} 允许把联动规格逐列登记为 {cmd:Y|X;Y|X}，也可加第三段样本条件 {cmd:Y|X|if}；例如 {cmd:y_alt|L2.x;y|x_alt|group_id==1}。两段写法沿用模型1的控制变量、固定效应、样本条件和标准误，第三段会与模型1的 {opt ifcond()} 合并。一次最多登记 40 列，足以覆盖替代变量、分组、滞后/超前和多维度实证规格，同时防止误输入造成无界组合。结果文件将模型1作为第1列，以“变量为行、稳健性规格为列”的标准回归三线表输出；为与基准回归保持一致，使用 A4 纵向页面，超过单页四列时自动拆为连续表，每张续表重复第1列。所有预设规格（显著和不显著）都会保留在 RTF、DO 和 CSV 中。{p_end}

{phang}{bf:HDFE 固定效应与聚类：}选择 {cmd:hdfe} 时，{opt absorb()} 和 {opt addfe()} 可填写多个吸收固定效应；交互固定效应可采用 {cmd:group_id#time_id} 形式。{opt cluster()} 与 {opt altcluster()} 同样接受 HDFE 支持的交互聚类写法。OLS、FE、RE、DID 和 IV 仍应填写其各自命令可接受的变量或因子设定。{opt keepsingletons} 将该选项传给 {cmd:reghdfe}/{cmd:ivreghdfe}，保留默认会删除的单例观测；这适合与显式虚拟变量的 {cmd:regress}/{cmd:xi:reg} 对齐，但可能使稳健标准误的显著性偏乐观，应按论文估计口径谨慎使用。{p_end}

{phang}{bf:内生性检验：}主模型可运行 2SLS-IV；填写 {opt endog()}、{opt instruments()} 后，内生性结果会同时保存每个内生变量的 IV 第一阶段、IV 第二阶段（2SLS）和排除工具变量联合 F 值，{opt ivcluster()} 可指定不同于基准的 IV 聚类变量。填写 {opt psmweight()} 时追加 PSM 加权结果；填写 {opt heckmansel()} 时同时报告 Heckman 第一阶段选择方程和第二阶段结果方程，并保留逆米尔斯比率。{opt ovbtest} 按完整模型、无控制无固定效应、仅固定效应和个体固定效应运行多规格遗漏变量偏误敏感性检验，并在表中报告 OVB F 值。“更多选项”提供 PSM、Heckman、动态 GMM 和 DML。内生性 RTF 将不同阶段按并列规格写入同一文件；阶段的被解释变量不同，不应直接比较跨方程系数大小。高级方法失败时记录警告并保留其他结果。{p_end}

{phang}{bf:机制检验：}{opt mediators()} 运行三步关联路径，{opt moderators()} 运行连续交互项。若某个中介方程采用不同聚类层级，可用 {opt medclusters()} 按 {cmd:中介变量=聚类变量;...} 登记；若研究数据已有预生成交互变量，可用 {opt modinteractions()} 按 {cmd:调节变量=交互变量;...} 登记。例如 {cmd:medclusters("mediator_a=cluster_id")} 和 {cmd:modinteractions("moderator_a=interaction_xw")}。运行结果与生成的 DO 均采用这些实际设定，并统一进入机制检验三件套；不单独保留图片或拆分数据文件。它们不自动建立因果机制。{p_end}

{phang}{bf:异质性分析：}{opt group()} 按最多 12 个预设数值类别估计；{opt groupbins(2/12)} 显式生成分位组规格；{opt grouptest} 运行核心变量与组别交互项的联合检验。连续变量不会被静默二分。{p_end}

{phang}{bf:相关性与模型诊断：}{opt corrvars()} 按指定顺序输出 Pearson 相关系数、双侧 P 值和两两有效观测数，最多30个变量；可以不运行基准回归。{opt vifcheck} 使用模型1的核心解释变量、内生变量和控制变量拟合辅助 OLS，并输出逐变量 VIF 与平均 VIF。{opt paneltests} 需要模型1的 {opt panel()} 和 {opt time()}，依次报告固定效应相对混合 OLS 的个体效应 F 检验、Breusch-Pagan 随机效应 LM 检验以及常规协方差下的 Hausman 检验。{opt ivtests} 需要 {opt endog()} 和 {opt instruments()}，报告第一阶段部分 R-squared、排除工具变量 F、最小特征值，以及可用时的过度识别检验。{p_end}

{pstd}这些统计量是模型诊断，不是自动选择或删除变量的规则。经典 Hausman 检验使用常规协方差重新估计，不能直接替代稳健/聚类设定下的专门检验；第一阶段 F 或过度识别检验也不能单独证明相关性、排除限制或工具变量外生性。{p_end}

{title:More options: advanced estimators}

{phang}{bf:PSM加权结果：}填写 {opt psmweight()} 后，若同时填写 {opt treat()}，加权结果方程将以该处理组变量作为核心效应；未填写时才回退到核心解释变量。期刊式内生性表把处理效应排在核心效应行，CSV和DO仍保留真实变量名，便于复核。{p_end}

{phang}{bf:Heckman已有校正项：}{opt heckmanimr()} 可填写数据中已有的数值型IMR变量；{opt heckmanoutcovars()} 可填写只进入结果方程、不进入选择方程的附加变量。变量名完全由用户选择，不针对某一篇论文写死。{p_end}

{phang}{bf:Common-timing event study.} {opt ptrend} 依据处理组中 {opt post()} 第一次等于 1 的时期识别共同政策时点，{opt ptbase()} 指定省略期，{opt ptlevel()} 指定置信水平，并将事件研究结果写入稳健性三件套。该实现不适用于交错处理时点。{p_end}

{phang}{bf:PSM.} {opt psmmethod(nearest)} 调用官方 {cmd:teffects psmatch}；{cmd:radius} 和 {cmd:kernel} 调用用户命令 {cmd:psmatch2}。{opt treat()} 指定0/1处理组，{opt psmcovars()} 指定匹配协变量，{opt psmtime()} 可加入时期因子，{opt psmneighbor()} 指定近邻数；{opt psmweight()} 接收外部流程或此前步骤生成的任意合法数值匹配权重变量。图形界面的“PSM匹配方法”可选择“近邻匹配”“半径匹配”“核匹配”或“预生成权重”；选择“预生成权重”时填写实际权重变量，插件会输出对应的加权结果和可复现 DO 命令。官方近邻匹配不接受 cluster VCE；选择 cluster 时插件改用 robust VCE并记录警告。{p_end}

{phang}{bf:Heckman.} {opt heckmansel()} 是选择指标，{opt heckmancovars()} 是选择方程协变量/排除限制，{opt heckmanfe} 加入已填写的固定效应和时间效应。HDFE + {opt heckmanfe} 时按常用的 Probit → 逆米尔斯比率（IMR）→ {cmd:reghdfe} 两步路径估计；其他模型使用官方 {cmd:heckman, twostep}。两种路径都会把选择方程作为“第一阶段”单独列入内生性 RTF，同时保留结果方程。若未填写 {opt heckmancovars()}，插件依次使用工具变量和控制变量。官方两步法使用自身的校正标准误，不接受普通 robust/cluster VCE。{p_end}

{phang}{bf:Dynamic GMM.} {opt gmmmethod(difference)} 调用 {cmd:xtabond}；{opt gmmmethod(system)} 调用 {cmd:xtdpdsys}。{opt gmmlags()} 指定因变量滞后阶数，{opt gmmextra()} 加入额外变量，{opt gmmtwostep} 请求两步估计。面板和时间变量必须齐全。{p_end}

{phang}{bf:Double machine learning.} {opt dmlmethod(partial)} 调用 Stata 18 官方 {cmd:xporegress}；{opt dmlmethod(iv)} 调用 {cmd:xpoivregress}。{opt dmlcontrols()}、{opt dmlinstruments()}、{opt dmlfolds()} 和 {opt reps()} 分别指定额外控制、DML 工具变量、交叉拟合折数和重抽样次数。{opt reps()} 允许 1 到 100；数值较大时计算会显著变慢。{p_end}

{title:Formatting, adjustment, and reports}

{phang}{opt adjustmethod(winsor)} 在临时副本中按 {opt winsorlow()} 和 {opt winsorhigh()} 对被解释变量、核心变量和控制变量缩尾，再运行一项稳健性规格。原始内存变量不被替换。{p_end}

{phang}{opt reportmode()} 为旧命令兼容保留，不再生成独立 DOCX；{opt decimals()} 控制 0 到 8 位显示小数；{opt statistic(se|t)} 控制括号统计量。{p_end}

{phang}{opt pstar1()}、{opt pstar2()}、{opt pstar3()} 控制 ***/**/* 的表格阈值，必须满足 0<pstar1<pstar2<pstar3<1。它们不修改估计值或样本。{p_end}

{phang}{opt missingmode(modelwise|preprocessed)} 记录缺失值处理口径。{cmd:modelwise} 使用各模型完整案例；{cmd:preprocessed} 表示用户已在预处理模块冻结处理方案。此选项不会静默插补或删除数据。{p_end}

{phang}{opt splitmed} 和 {opt splithet} 分别导出中介、异质性单独表。{p_end}

{title:Per-module publication package}

{pstd}每个本次作为主任务实际成功运行的模块在 {opt outdir()} 下使用固定的“模块名结果”文件夹。重复运行同一模块会直接覆盖该文件夹中的同名三件套，不再新建带日期时间的结果文件夹；为完成其他模块而估计的模型1、第一阶段或其他计算依赖只进入当前主模块的结果，不会覆盖依赖模块的独立文件夹。未填写、失败或没有有效结果的模块不生成空文件夹：{p_end}

{p 8 12 2}{cmd:描述性统计分析结果/描述性统计分析.rtf/.do/.csv}{p_end}
{p 8 12 2}{cmd:基准回归分析结果/基准回归分析.rtf/.do/.csv}{p_end}
{p 8 12 2}{cmd:稳健性检验结果/稳健性检验.rtf/.do/.csv}{p_end}
{p 8 12 2}{cmd:内生性检验结果/内生性检验.rtf/.do/.csv}{p_end}
{p 8 12 2}{cmd:机制检验结果/机制检验.rtf/.do/.csv}{p_end}
{p 8 12 2}{cmd:异质性分析结果/异质性分析.rtf/.do/.csv}{p_end}
{p 8 12 2}{cmd:相关性与模型诊断结果/相关性与模型诊断.rtf/.do/.csv}{p_end}

{phang}{bf:RTF.} 可直接用 Word 打开。所有分析模块统一使用 A4 纵向页面、四边 720 twips、Times New Roman、标题 12 磅、正文 9 磅、1.5 倍行距、普通段落和制表位生成标准三线表；多规格表超过单页四列时在同一文件中自动续表，稳健性续表重复基准模型。文件不创建 Word 表格对象，因此即使开启“查看网格线”，也只显示表顶线、表头分隔线和表底线。中文按标准 RTF Unicode 写入；左列始终使用 Stata 原始变量名，不读取变量标签，也不做翻译。多组基准回归按 `(1)`—`(4)` 横向合并，缺少的系数留空，核心变量和控制变量在前、常数项在后，底部输出控制变量、时间固定效应、个体固定效应、N 和 Adjusted R-squared。稳健性、内生性、机制与异质性只要形成回归表，也按各列实际估计规格输出这三项设计行，不用基准模型设定替代高级规格的真实设定。描述性统计按 {cmd:variable_order}，回归结果按 {cmd:specification_order}、{cmd:term_order} 输出。CSV 仍保留 {cmd:variable_label} 作为元数据。{p_end}

{pstd}每个 RTF 表格下方自动追加一段基于当前表实际数值的结果说明，按“结果解读—发现的问题—可能影响—处理建议”顺序组织；没有触发的问题不重复堆砌通用定义。描述性统计保留中文表题和表注，仅将统计指标列名输出为英文（{cmd:Variable}、{cmd:N}、{cmd:Mean}、{cmd:SD}、{cmd:Min}、{cmd:Max}）；变量名仍保持 Stata 原始名称。回归表和诊断表报告表内系数、P 值、N、拟合优度、相关系数、VIF及第一阶段统计量，并针对实际发现给出影响和处理建议。自动文字只读取本次实际结果，不修改数据、模型或显著性，也不会把不显著结果解释为显著。{p_end}

{phang}{bf:DO.} 采用人工编写的论文实证脚本风格，首行直接进入数据导入，不写插件名称、版本、运行编号、安装命令或插件专用导出命令。脚本集中定义 {cmd:$controls}，逐条写出 {cmd:tabstat}、{cmd:regress}/{cmd:reghdfe}/{cmd:xtreg}/{cmd:ivregress} 等命令，以 {cmd:est store m1}—{cmd:m4} 保存模型，并用一次 {cmd:esttab m1 ... m4} 横向生成同名 RTF 和 CSV；这些扩展命令按已安装处理。{p_end}

{phang}{bf:CSV.} 描述性表保留样本数、缺失数、均值、标准差、最小值、最大值、变量角色和顺序。回归表保留未舍入系数、标准误、t 值、p 值、置信区间、N、R-squared、星号、规格标签和顺序字段。{p_end}

{pstd}运行结束后，Results 窗口会把每个成功模块的 RTF、DO、CSV 文件名显示为蓝色可点击链接。点击 DO 会进入 Stata Do-file Editor，点击 RTF/CSV 会交给系统默认关联程序打开。描述性统计在 Results 窗口中按“变量为行，N、缺失数、均值、标准差、最小值、最大值为列”一次显示为一张完整表，不再按变量拆成多个小框。{p_end}

{pstd}只运行描述性统计或基准回归时，仅更新相应的固定结果文件夹。运行稳健性、内生性、机制、异质性或模型诊断时，模型1仍按需要估计，并可作为当前模块的比较列，但不会更新此前独立生成的基准回归三件套。一次运行多个扩展模块时只更新这些主模块；明确填写第2—4组基准模型，或在基准回归编辑器中把模型1直接选为 2SLS-IV 时，基准回归也被视为显式主模块。命令行中的 {opt replace} 为向后兼容保留，模块三件套始终按覆盖方式写出。{p_end}

{title:Output order and artifacts}

{pstd}实证输出根目录最终只保留固定的模块结果文件夹；每个模块文件夹只保留同名 RTF、DO、CSV 三个文件。{cmd:_results.*}、{cmd:.ster}、{cmd:_diagnostics.dta}、拆分数据、文本、图片、DOCX 和日志都只在临时目录参与计算并于结束时清除。程序也会清理旧版本遗留在输出根目录中的这些工作文件。{p_end}

{pstd}{cmd:e(journalone_package_dir)} 保存输出根目录，{cmd:e(journalone_package_dirs)} 保存本次实际更新的模块文件夹，{cmd:e(journalone_published_modules)} 保存实际成功写出完整三件套的模块名称。{cmd:e(journalone_modules)} 仍表示本次完成的计算，其中可能包含只作为其他模块依赖、未取得独立目录覆盖权的 {cmd:baseline}。各模块目录和正式文件分别存放在 {cmd:e(journalone_descriptive_dir)}、{cmd:e(journalone_descriptive_rtf)}、{cmd:e(journalone_descriptive_do)}、{cmd:e(journalone_descriptive_csv)} 等对应返回值中；不再返回已删除的工作文件路径。{p_end}

{pstd}所有临时缩尾、重分类和图形估计都在 {cmd:preserve}/{cmd:restore} 副本中运行；程序在内存中比较运行前后数据签名。数据预处理模块自身的审计和样本流文件不受本项实证输出精简影响。{p_end}

{title:显著组合窗口}

{pstd}{cmd:db journalone_signif} 打开包含“显著组合”和“更多选项”两个页签的独立窗口。第一页填写 Y/X、固定效应、聚类变量、面板 ID/时间变量、必留与候选控制、稳健性、机制和异质性规格；第二页填写 X→Y、X→M、X×W→Y 预期方向、基准/中介/调节置信区间和最少控制变量。{p_end}

{pstd}{cmd:journalone_signif} 只枚举预先填写的规格，不按 p 值筛除结果，不复制黑箱“只找显著模型”的行为。页面内的密钥框用于首次验证插件访问授权，采用密码掩码且不记忆，不会写入结果文件。{cmd:panel()} 和 {cmd:time()} 用于面板模型及滞后/滞前运算，{cmd:subsample()} 会作为每条估计的 {cmd:if} 条件。政策窗口、安慰剂和平行趋势字段当前只写入审计说明，等待研究者提供明确设计。{p_end}

{pstd}输出目录默认为 {cmd:显著组合结果/}，包括 {cmd:显著组合.rtf/.do/.csv}、规格数据和审计文本；RTF 为 A4、1.5 倍行距三线表，按“规格—变量—估计量”长表排列，所有成功规格（含不显著者）均保留。{p_end}

{title:Important limits}

{pstd}PASS 只验证命令执行和产物生成，不证明识别假设、因果有效性、变量构造、外部有效性或期刊录用。PSM 不解决不可观测混杂；Heckman 应有理论支持的排除限制；动态 GMM 仍需检查工具数量、序列相关和过度识别；DML 的交叉拟合不替代研究设计。RDD、合成控制和交错 DID 尚未放入通用按钮。{p_end}

{pstd}JournalOne 不会通过反复改变数据把解释变量、中介或调节变量调到目标 p 值。界面中的 p 值选项只定义结果表显著性星号。{p_end}

{title:Examples}

{p 4 8 2}{cmd:. journalone, descvars(y x c1 c2) ifcond(year>=2010)}{p_end}

{p 4 8 2}{cmd:. journalone, corrvars(y x c1 c2) nodesc}{p_end}

{p 4 8 2}{cmd:. journalone, model(ols) depvar(y) indepvars(x) controls(c1 c2) nodesc}{p_end}

{p 4 8 2}{cmd:. journalone, model(hdfe) depvar(y) indepvars(x) vcetype(cluster) cluster(id) model2(hdfe) depvar2(y) indepvars2(x) controls2(c1 c2) vcetype2(cluster) cluster2(id) model3(hdfe) depvar3(y) indepvars3(x) controls3(c1 c2) absorb3(year) vcetype3(cluster) cluster3(id) model4(hdfe) depvar4(y) indepvars4(x) controls4(c1 c2) absorb4(id year) vcetype4(cluster) cluster4(id) nodesc}{p_end}

{p 4 8 2}{cmd:. journalone, model(ols) depvar(y) indepvars(x) controls(c1 c2) descvars(y x c1 c2)}{p_end}

{p 4 8 2}{cmd:. journalone, model(fe) depvar(y) indepvars(x) controls(c1 c2) panel(id) time(year) corrvars(y x c1 c2) vifcheck paneltests nodesc}{p_end}

{p 4 8 2}{cmd:. journalone, model(iv) depvar(y) controls(c1 c2) endog(x) instruments(z1 z2) corrvars(y x z1 z2 c1 c2) vifcheck ivtests nodesc}{p_end}

{p 4 8 2}{cmd:. journalone, model(hdfe) depvar(outcome) indepvars(exposure) controls(control_a control_b) absorb(entity_id period) vcetype(cluster) cluster(cluster_id) ovbtest endog(exposure) instruments(instrument_z) psmweight(match_weight) heckmansel(selected) heckmancovars(exposure control_a control_b selection_exclusion) heckmanfe nodesc}{p_end}

{p 4 8 2}{cmd:. journalone, model(ols) depvar(y) indepvars(x) controls(c1 c2) vcetype(robust)}{p_end}

{p 4 8 2}{cmd:. journalone, model(did) depvar(y) treat(treated) post(post) controls(c1 c2) panel(id) time(year) vcetype(cluster) cluster(id) ptrend ptbase(-1)}{p_end}

{p 4 8 2}{cmd:. journalone, model(ols) depvar(y) indepvars(x) controls(c1 c2) treat(treated) psmmethod(nearest) psmcovars(c1 c2) psmneighbor(1)}{p_end}

{p 4 8 2}{cmd:. journalone, model(ols) depvar(y_selected) indepvars(x) controls(c1 c2) heckmansel(selected) heckmancovars(z c1 c2)}{p_end}

{p 4 8 2}{cmd:. journalone, model(fe) depvar(y) indepvars(x) controls(c1 c2) panel(id) time(year) gmmmethod(difference) gmmlags(1)}{p_end}

{p 4 8 2}{cmd:. journalone, model(iv) depvar(y) controls(c1 c2) endog(x) instruments(z) dmlmethod(iv) dmlinstruments(z) dmlcontrols(w) dmlfolds(5) reps(1)}{p_end}

{title:Remote installation and authorization}

{p 8 12 2}{cmd:. do "https://xm-xm56.github.io/journalone-stata/install.do"}{p_end}
{p 8 12 2}{cmd:. journalone_license, activate("key supplied by the author")}{p_end}
{p 8 12 2}{cmd:. journalone_license, status}{p_end}
{p 8 12 2}{cmd:. journalone_update}{p_end}

{pstd}安装包不包含明文密钥。首次使用可直接在“实证分析”“数据预处理”或“显著组合”页面的密码掩码输入栏填写发布者提供的密钥，然后点击“激活并解锁”。未激活时，变量选择框、分析选项和基准回归设置均被禁用；即使已经载入或更换数据也不会解锁。验证成功后控件立即启用，本机后续可以留空运行。页面使用隐藏验证命令，密钥不会写入输出文件；公共 JournalOne 命令仍会在后端再次校验授权。纯本地 ado 校验用于普通访问控制，不是不可绕过的 DRM。{p_end}

{pstd}三个插件页面均提供“一键更新”。该入口无需授权，自动使用首次安装时记录的来源覆盖公共包文件；更新完成后关闭并重新打开当前窗口即可。发布者私有的 Excel 密钥库不会被下载。{p_end}

{title:Menu installation}

{p 8 12 2}{cmd:. journalone_menu}{p_end}

{pstd}推荐的一条命令安装脚本会自动调用 {cmd:journalone_menu}。该命令安全地向个人 {cmd:profile.do} 追加菜单块、立即刷新当前窗口，不会清空既有用户菜单，并加入“一键更新”入口。详细数据清洗说明见 {help journalone_prep}。{p_end}
