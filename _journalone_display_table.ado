*! version 0.9.15 18aug2026

capture program drop _journalone_display_table
program define _journalone_display_table
    version 16.0
    * Stata command names are limited to 32 characters.  Keep this public
    * wrapper short while the implementation remains separately testable.
    capture findfile _journalone_display_results_table.ado
    if _rc exit 111
    local implementation `"`r(fn)'"'
    quietly do `"`implementation'"'
    _jo_display_results_table `0'
end
