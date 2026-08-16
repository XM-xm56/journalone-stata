*! version 0.8.0 15aug2026

capture program drop _journalone_fit
program define _journalone_fit, eclass
    version 16.0
    syntax , MODEL(string) DEPVAR(string)                              ///
        [ INDEPVARS(string) CONTROLS(string)                           ///
          PANEL(string) TIME(string) ABSORB(string) TIMEFE             ///
          VCETYPE(string) CLUSTER(string) TREAT(string)               ///
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
        local comma ""
        if "`vceopt'" != "" local comma ", `vceopt'"
        ivregress 2sls `depvar' `indepvars' `controls' `fe_terms' `time_terms' ///
            (`endog' = `instruments') `ifqual' `comma'
    }
end
