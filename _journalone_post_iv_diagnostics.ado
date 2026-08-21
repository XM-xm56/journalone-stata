*! version 0.9.18 20aug2026

capture program drop _journalone_post_iv_diagnostics
program define _journalone_post_iv_diagnostics
    version 16.0
    syntax , HANDLE(name) RUNID(string) SPEC(string) OUTCOME(string)

    * ivreghdfe exposes the paper-standard weak-identification statistics in
    * e().  Keep them as ordinary result rows so CSV, RTF, and the generated
    * do-file describe the same structural second-stage specification.  The
    * helper is deliberately a no-op for official ivregress or estimators that
    * do not expose these scalars.
    if !inlist("`spec'", "main", "iv_2sls") exit

    scalar __jo_ivdiag_n = .
    scalar __jo_ivdiag_r2 = .
    scalar __jo_ivdiag_r2a = .
    capture scalar __jo_ivdiag_n = e(N)
    capture scalar __jo_ivdiag_r2 = e(r2)
    capture scalar __jo_ivdiag_r2a = e(r2_a)
    if missing(__jo_ivdiag_r2a) capture scalar __jo_ivdiag_r2a = e(r2_a_within)

    scalar __jo_ivdiag_kp_lm = .
    scalar __jo_ivdiag_cd_f = .
    scalar __jo_ivdiag_kp_f = .
    scalar __jo_ivdiag_kp_p = .
    scalar __jo_ivdiag_cd_p = .
    capture scalar __jo_ivdiag_kp_lm = e(idstat)
    capture scalar __jo_ivdiag_cd_f = e(cdf)
    capture scalar __jo_ivdiag_kp_f = e(widstat)
    capture scalar __jo_ivdiag_kp_p = e(idp)

    if !missing(__jo_ivdiag_kp_lm) {
        post `handle' ("`runid'") ("`spec'") ("`outcome'") (996) ///
            ("KP_LM") (__jo_ivdiag_kp_lm) (.) (__jo_ivdiag_kp_p) ///
            (.) (.) (__jo_ivdiag_n) (__jo_ivdiag_r2) (__jo_ivdiag_r2a)
    }
    if !missing(__jo_ivdiag_cd_f) {
        post `handle' ("`runid'") ("`spec'") ("`outcome'") (997) ///
            ("CD_F") (__jo_ivdiag_cd_f) (.) (.) ///
            (.) (.) (__jo_ivdiag_n) (__jo_ivdiag_r2) (__jo_ivdiag_r2a)
    }
    if !missing(__jo_ivdiag_kp_f) {
        post `handle' ("`runid'") ("`spec'") ("`outcome'") (998) ///
            ("KP_F") (__jo_ivdiag_kp_f) (.) (.) ///
            (.) (.) (__jo_ivdiag_n) (__jo_ivdiag_r2) (__jo_ivdiag_r2a)
    }
end
