*! version 0.9.18 05sep2026

capture program drop _journalone_fit
program define _journalone_fit, eclass
    version 16.0
    syntax , MODEL(string) DEPVAR(string)                              ///
        [ INDEPVARS(string) CONTROLS(string)                           ///
          PANEL(string) TIME(string) ABSORB(string) TIMEFE             ///
          VCETYPE(string) CLUSTER(string) TREAT(string) IVCLUSTER(string) ///
          POSTVAR(string) ENDOG(string) INSTRUMENTS(string)            ///
          IFCOND(string) ]

    local ifqual ""
    if strtrim(`"`ifcond'"') != "" local ifqual `"if `ifcond'"'

    local fe_terms ""
    foreach fevar of local absorb {
        local fe_terms "`fe_terms' i.`fevar'"
    }
    local time_terms ""
    if "`timefe'" != "" {
        if "`time'" == "" {
            display as error "timefe 需要 time()"
            exit 198
        }
        local time_terms "i.`time'"
    }

    local vceopt ""
    if "`vcetype'" == "robust" local vceopt "vce(robust)"
    else if "`vcetype'" == "cluster" {
        if "`cluster'" == "" {
            display as error "cluster VCE 需要 cluster()"
            exit 198
        }
        local vceopt "vce(cluster `cluster')"
    }
    else if "`vcetype'" != "conventional" {
        display as error "未知 VCE：`vcetype'"
        exit 198
    }

    if "`panel'" != "" {
        if "`time'" != "" quietly xtset `panel' `time'
        else quietly xtset `panel'
    }

    if "`model'" == "ols" {
        local comma ""
        if "`vceopt'" != "" local comma ", `vceopt'"
        regress `depvar' `indepvars' `controls' `fe_terms' `time_terms' `ifqual' `comma'
    }
    else if "`model'" == "hdfe" {
        local hdfe_absorb = strtrim(`"`absorb'"')
        if "`timefe'" != "" & !strpos(" `hdfe_absorb' ", " `time' ") {
            local hdfe_absorb = strtrim("`hdfe_absorb' `time'")
        }
        local hdfe_absorbopt "noabsorb"
        if strtrim(`"`hdfe_absorb'"') != "" local hdfe_absorbopt "absorb(`hdfe_absorb')"
        local hdfe_options ", `hdfe_absorbopt'"
        if "`vceopt'" != "" local hdfe_options "`hdfe_options' `vceopt'"
        if "$JOURNALONE_KEEP_SINGLETONS" == "1" local hdfe_options "`hdfe_options' keepsingletons"
        reghdfe `depvar' `indepvars' `controls' `ifqual' `hdfe_options'
    }
    else if "`model'" == "fe" {
        local opts ", fe"
        if "`vceopt'" != "" local opts "`opts' `vceopt'"
        xtreg `depvar' `indepvars' `controls' `fe_terms' `time_terms' `ifqual' `opts'
    }
    else if "`model'" == "re" {
        local opts ", re"
        if "`vceopt'" != "" local opts "`opts' `vceopt'"
        xtreg `depvar' `indepvars' `controls' `fe_terms' `time_terms' `ifqual' `opts'
    }
    else if "`model'" == "did" {
        local comma ""
        if "`vceopt'" != "" local comma ", `vceopt'"
        regress `depvar' i.`treat'##i.`postvar' `indepvars' `controls' ///
            i.`panel' i.`time' `fe_terms' `ifqual' `comma'
    }
    else if "`model'" == "iv" {
        * Prefer ivreghdfe when an absorption specification is supplied and
        * the command is available.  This matches paper-style commands such
        * as `ivreghdfe y x (endog = z), absorb(id year) cluster(g)`.  The
        * official ivregress fallback keeps the module usable on a clean
        * Stata installation without ivreghdfe.
        * Match the HDFE/GUI semantics: a checked time-FE box contributes
        * time() to ivreghdfe's absorb() dimensions too.  Without this,
        * the IV branch silently estimated only the literal absorb() list.
        local iv_absorb = strtrim(`"`absorb'"')
        if "`timefe'" != "" & "`time'" != "" & ///
            !strpos(" `iv_absorb' ", " `time' ") {
            local iv_absorb = strtrim("`iv_absorb' `time'")
        }
        local has_absorb = (strtrim(`"`iv_absorb'"') != "")
        capture which ivreghdfe
        local has_ivreghdfe = (_rc == 0)
        local iv_cluster "`ivcluster'"
        if strtrim("`iv_cluster'") == "" local iv_cluster "`cluster'"
        local iv_cluster_temp ""
        if strpos("`iv_cluster'", "#") {
            * ivreghdfe does not accept factor interactions in cluster();
            * materialize the interaction only for this estimation call.
            tempvar iv_cluster_tempvar
            local cluster_parts = subinstr("`iv_cluster'", "#", " ", .)
            local cluster_parts = subinstr("`cluster_parts'", "i.", "", .)
            local cluster_parts = subinstr("`cluster_parts'", "c.", "", .)
            quietly egen long `iv_cluster_tempvar' = group(`cluster_parts')
            local iv_cluster "`iv_cluster_tempvar'"
            local iv_cluster_temp "`iv_cluster_tempvar'"
        }
        * The endogenous variables belong only inside the parenthesized IV
        * block.  Users often also list them in indepvars(); remove them
        * (and any instrument accidentally listed as a control) from the
        * ordinary RHS so generated/runtime commands remain valid for one or
        * many endogenous variables.
        local iv_rhs = strtrim(itrim(`"`indepvars' `controls'"'))
        foreach endogenous_variable of local endog {
            local iv_rhs : list iv_rhs - endogenous_variable
        }
        foreach instrument_variable of local instruments {
            local iv_rhs : list iv_rhs - instrument_variable
        }
        local iv_rhs : list uniq iv_rhs
        if `has_absorb' & `has_ivreghdfe' {
            local iv_options "absorb(`iv_absorb')"
            if "`vcetype'" == "robust" local iv_options "`iv_options' robust"
            else if "`vcetype'" == "cluster" local iv_options "`iv_options' cluster(`iv_cluster')"
            if "$JOURNALONE_KEEP_SINGLETONS" == "1" local iv_options "`iv_options' keepsingletons"
            ivreghdfe `depvar' `iv_rhs' ///
                (`endog' = `instruments') `ifqual', `iv_options'
        }
        else {
            local comma ""
            if "`vceopt'" != "" local comma ", `vceopt'"
            ivregress 2sls `depvar' `iv_rhs' `fe_terms' `time_terms' ///
                (`endog' = `instruments') `ifqual' `comma'
        }
        if "`iv_cluster_temp'" != "" capture drop `iv_cluster_temp'
    }
end
