{smcl}
{* *! version 0.9.5 17aug2026}{...}
{vieweralsosee "JournalOne authorization" "help journalone_license"}{...}
{vieweralsosee "JournalOne estimation" "help journalone"}{...}
{vieweralsosee "misstable" "help misstable"}{...}
{vieweralsosee "duplicates" "help duplicates"}{...}
{vieweralsosee "encode" "help encode"}{...}
{vieweralsosee "destring" "help destring"}{...}

{title:Title}

{p 4 8 2}{cmd:journalone_prep} — 期刊研究用、可审计、可复现的数据预处理原生插件{p_end}

{title:Open the GUI}

{p 8 12 2}{cmd:. journalone_prep}{p_end}

{pstd}首次使用可在页面“输出与复现”区域的“密钥”输入栏直接填写发布者提供的授权密钥，也可通过 {help journalone_license} 激活。输入栏使用密码掩码且不记忆。{p_end}
{p 8 12 2}{cmd:. db journalone_prep}{p_end}

{title:Syntax}

{p 8 12 2}
{cmd:journalone_prep,}
[{opt vars(varlist)}
{opt idvar(varname)} {opt timevar(varname)}
{opt mergefile(filename)} {opt mergekey(varlist)} {opt mergetype(string)}
{opt recodevar(varname)} {opt recodefrom(string)} {opt recodeto(string)}
{opt dropvar1(varname)} {opt dropop1(string)} {opt dropvalue1(string)}
{opt dropvar2(varname)} {opt dropop2(string)} {opt dropvalue2(string)}
{opt dropvar3(varname)} {opt dropop3(string)} {opt dropvalue3(string)}
{opt dropif(expression)}
{opt keepif(expression)}
{opt dupmethod(string)} {opt dupkey(varlist)}
{opt missmethod(string)} {opt missvars(varlist)} {opt missby(varlist)}
{opt outmethod(string)} {opt outvars(varlist)}
{opt plow(#)} {opt phigh(#)} {opt outby(varlist)}
{opt logvars(varlist)} {opt logmode(string)}
{opt zvars(varlist)} {opt encodevars(varlist)} {opt destringvars(varlist)}
{opt outdir(path)} {opt prefix(name)} {opt saveclean}]

{title:Step 1 — import and merge}

{phang}{opt mergefile()} optionally selects an external {cmd:.dta} file. {opt mergekey()} lists the same key variable names in the master and using data; {opt mergetype()} accepts {cmd:1:1}, {cmd:m:1}, or {cmd:1:m} and defaults to {cmd:1:1}.{p_end}
{pstd}The master observations and matched observations are retained. Using-only observations are excluded, and matched, master-only, and using-only counts are written to the sample-flow and audit files. The command never overwrites the source file or the original in-memory master data.{p_end}

{title:Fixed execution order}

{p 8 12 2}1. inventory and sign the raw in-memory data;{p_end}
{p 8 12 2}2. merge the optional external file and record merge counts;{p_end}
{p 8 12 2}3. apply the value conversion and retained-sample condition;{p_end}
{p 8 12 2}4. report or process duplicate records;{p_end}
{p 8 12 2}5. report, delete, or impute missing values;{p_end}
{p 8 12 2}6. report, winsorize, or trim outliers;{p_end}
{p 8 12 2}7. generate transformations and type conversions;{p_end}
{p 8 12 2}8. apply up to three deletion rows and the free deletion condition;{p_end}
{p 8 12 2}9. declare the cleaned panel copy when valid, inventory and save it with all audit artifacts, then restore the original data.{p_end}

{title:Step 2 — variable inventory}

{phang}{opt vars()} defines the variables included in the raw-data audit. If omitted, all variables are audited.{p_end}
{pstd}For every selected variable the dictionary records its name, storage type, variable label, total observations, nonmissing count, missing count and percentage, and number of unique values. Numeric variables additionally receive mean, standard deviation, minimum, p1, p25, median, p75, p99, and maximum.{p_end}

{title:Step 3 — data structure and keys}

{phang}{opt idvar()} identifies the panel subject, such as firm, person, or city.{p_end}
{phang}{opt timevar()} identifies a numeric time variable.{p_end}
{pstd}When both are supplied, the audit reports surplus ID-by-time records. It also reports the number of panel units, the number of observed time values, and the minimum and maximum number of records per unit. After all requested cleaning steps, the output copy is declared with {cmd:xtset idvar timevar} when the variables are valid and the cleaned ID-by-time key is unique. With only {opt idvar()}, the command attempts {cmd:xtset idvar}. The audit and sample-flow files record whether declaration succeeded and its return code. A failed declaration produces a warning but never changes the original in-memory data.{p_end}

{title:Step 4 — freeze the research sample}

{phang}{opt keepif()} supplies the Boolean condition for the retained sample, for example {cmd:year>=2010 & year<=2025 & !missing(industry)}.{p_end}
{pstd}The condition is evaluated before duplicate and missing-value processing. The sample-flow file records observations before and after the condition. A condition that removes every observation is treated as an error.{p_end}

{title:Step 5 — duplicates}

{synoptset 21 tabbed}{...}
{synopthdr:dupmethod()}
{synoptline}
{synopt:{cmd:report}}report findings only; this is the default{p_end}
{synopt:{cmd:exact}}delete observations that are identical on all original variables{p_end}
{synopt:{cmd:keyfirst}}for each {cmd:dupkey()}, retain the first record in original row order{p_end}
{synopt:{cmd:keylast}}for each {cmd:dupkey()}, retain the last record in original row order{p_end}
{synoptline}

{pstd}{opt dupkey()} is mandatory for {cmd:keyfirst} and {cmd:keylast}. The audit separately reports surplus exact duplicates, surplus specified-key duplicates, and surplus ID-by-time records. Key selection must be justified by the data-generating process; the plugin cannot determine which duplicate is substantively correct.{p_end}

{title:Step 6 — missing values}

{synoptset 21 tabbed}{...}
{synopthdr:missmethod()}
{synoptline}
{synopt:{cmd:report}}report missing rows only; this is the default{p_end}
{synopt:{cmd:drop}}complete-case deletion over {cmd:missvars()}{p_end}
{synopt:{cmd:mean}}mean imputation into new variables{p_end}
{synopt:{cmd:median}}median imputation into new variables{p_end}
{synoptline}

{phang}{opt missvars()} is mandatory for deletion or imputation. With {cmd:report}, omitting it uses the audited variables.{p_end}
{phang}{opt missby()} requests within-group imputation, for example {cmd:industry year}. If a group has no usable value, the command falls back to the full-sample statistic.{p_end}
{pstd}Imputation supports numeric variables only and never overwrites them. For variable {cmd:x}, the completed copy is named {cmd:mi_x}, and {cmd:m_x} flags observations that were originally missing. If a generated name already exists, a numeric suffix is added. Mean or median imputation is a convenience operation, not evidence that MCAR/MAR assumptions hold; multiple imputation or model-based handling may be required in the final design.{p_end}

{title:Step 7 — outliers and value conversion}

{phang}{opt recodevar()} with {opt recodefrom()} and {opt recodeto()} converts one exact value in one variable. Numeric variables require numeric literals; string variables are compared as text. The number of changed observations is recorded, and the original variable is changed only inside the cleaned copy.{p_end}

{synoptset 23 tabbed}{...}
{synopthdr:outmethod()}
{synoptline}
{synopt:{cmd:report}}do not modify values; this is the default{p_end}
{synopt:{cmd:winsor}}generate a winsorized {cmd:w_} copy of each selected variable{p_end}
{synopt:{cmd:winsorreplace}}winsorize the selected names in the output copy{p_end}
{synopt:{cmd:trim}}delete a row if any selected variable lies outside its limits{p_end}
{synoptline}

{phang}{opt outvars()} lists numeric variables. It is mandatory for all modifying methods.{p_end}
{phang}{opt plow()} and {opt phigh()} specify percentage cut points and default to 1 and 99. They must satisfy 0 <= {it:plow} < {it:phigh} <= 100.{p_end}
{phang}{opt outby()} computes cut points within groups, for example industry-by-year.{p_end}
{pstd}Outlier thresholds should be chosen before inspecting preferred regression significance. Trimming changes the estimation population; winsorization changes the variable distribution. Both decisions belong in the paper and robustness analysis.{p_end}

{title:Step 8 — transformations and types}

{phang}{opt logvars()} generates {cmd:ln_} variables. {opt logmode(ln)} requires x>0; {opt logmode(ln1p)} computes ln(1+x) and requires x>-1. Values outside the domain become missing and are counted in the audit.{p_end}
{phang}{opt zvars()} generates {cmd:z_} variables using the cleaned-copy sample mean and standard deviation. A constant or insufficiently observed variable produces missing values and a warning.{p_end}
{phang}{opt encodevars()} applies official {cmd:encode} to string categories and generates {cmd:cat_} variables with value labels.{p_end}
{phang}{opt destringvars()} applies strict {cmd:destring} and generates {cmd:num_} variables. It deliberately does not use {cmd:force}; unexpected characters stop the run instead of being silently converted to missing.{p_end}
{pstd}Transformations operate on the selected original variable names. Imputed and transformed versions remain separate so the researcher must explicitly choose the regression measure.{p_end}

{title:Step 9 — sample deletion rows}

{phang}{opt dropvar1()}, {opt dropvar2()}, and {opt dropvar3()} each define an optional sequential deletion rule. Pair each with {opt dropop1()}—{opt dropop3()} ({cmd:==}, {cmd:!=}, {cmd:>}, {cmd:>=}, {cmd:<}, {cmd:<=}, {cmd:missing}, or {cmd:nonmissing}) and, except for missingness operators, the corresponding {opt dropvalue1()}—{opt dropvalue3()}.{p_end}
{phang}{opt dropif()} is a free Stata condition; observations satisfying it are deleted after the three rows. Each rule writes before/after counts and its expression to the sample-flow file. If any requested operation removes all observations, the run stops and the outer {cmd:preserve}/{cmd:restore} restores the source data.{p_end}

{title:Step 10 — outputs and reproducibility}

{phang}{opt outdir()} sets the output directory; the default is {cmd:journalone_prep_output}.{p_end}
{phang}{opt prefix()} sets the run-name prefix; the default is {cmd:prep}.{p_end}
{phang}{opt saveclean} writes the cleaned data copy. Audit artifacts are written whether or not this option is supplied.{p_end}
{pstd}If a valid {opt idvar()} (and optional {opt timevar()}) was supplied, the saved {cmd:_clean.dta} retains the corresponding {cmd:xtset} metadata. String IDs, missing panel keys, or repeated ID-by-time observations prevent declaration and are reported through {cmd:panel_set_rc} instead of being silently repaired.{p_end}

{pstd}Every run receives a timestamped ID and writes:{p_end}
{p 8 12 2}1. full text execution log ({cmd:.log});{p_end}
{p 8 12 2}2. cleaned data ({cmd:_clean.dta}) when requested;{p_end}
{p 8 12 2}3. raw and cleaned variable dictionary ({cmd:_dictionary.dta/.csv});{p_end}
{p 8 12 2}4. sample-flow table ({cmd:_flow.dta/.csv});{p_end}
{p 8 12 2}5. audit summary ({cmd:_audit.txt}); and{p_end}
{p 8 12 2}6. a replayable command file ({cmd:_recipe.do}).{p_end}

{pstd}The audit includes raw and cleaned data signatures and a post-restore signature. {cmd:memory_data_unchanged=1} confirms that the command restored the original in-memory data. A PASS status confirms execution and artifact integrity only; it does not establish causal validity, correct sample construction, or journal acceptance.{p_end}

{title:Examples}

{p 4 8 2}{cmd:. journalone_prep, vars(id year y x controls) idvar(id) timevar(year) saveclean}{p_end}

{p 4 8 2}{cmd:. journalone_prep, vars(id year y x c1 c2) idvar(id) timevar(year) keepif(year>=2012 & year<=2025) dupmethod(keyfirst) dupkey(id year) missmethod(median) missvars(x c1 c2) missby(industry year) outmethod(winsor) outvars(y x) outby(year) plow(1) phigh(99) logvars(x) zvars(x c1 c2) outdir(prep_results) prefix(main_sample) saveclean}{p_end}

{p 4 8 2}{cmd:. journalone_prep, encodevars(region ownership) destringvars(revenue_text) outdir(results/prep) prefix(types) saveclean}{p_end}

{p 4 8 2}{cmd:. journalone_prep, mergefile("firm_attributes.dta") mergekey(firm_id year) mergetype(1:1) recodevar(region) recodefrom("华东") recodeto("East") dropvar1(score) dropop1(>) dropvalue1(99) dropvar2(industry) dropop2(missing) dropif(year<2010) outdir(results/clean) prefix(main) saveclean}{p_end}

{title:Recommended reporting checklist}

{p 8 12 2}1. state the original source, unit of observation, period, and raw sample size;{p_end}
{p 8 12 2}2. define the unique key and explain duplicate resolution;{p_end}
{p 8 12 2}3. disclose exclusions in the order shown by the sample-flow table;{p_end}
{p 8 12 2}4. report missingness by key variable and justify deletion or imputation;{p_end}
{p 8 12 2}5. state outlier thresholds, grouping level, and whether values or rows changed;{p_end}
{p 8 12 2}6. define every transformation and retain the raw measure for robustness checks;{p_end}
{p 8 12 2}7. archive the recipe, audit, dictionary, sample flow, log, and cleaned data together.{p_end}

{title:Menu installation}

{p 8 12 2}{cmd:. journalone_menu}{p_end}

{pstd}After installation, choose {bf:用户 > 期刊实证工具 > 数据预处理}. The installer appends its own marked block to the personal {cmd:profile.do} and does not clear or replace existing menus.{p_end}
