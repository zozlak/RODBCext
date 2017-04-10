## Test environments

* local Linux install, x64, R 3.3.2
* local Windows install, x64, R 3.3.3
* travis.ci Linux, x64, R 3.3.3
* travis.ci Linux, x64, R 3.4.0 beta (r72499)
* devtools win-builder, R 3.4.0 beta (r72499)

## R CMD check results

* There were no ERRORs nor WARNINGs.
* Local and travis.ci builds generated no NOTEs.
* Win-builder generated 1 NOTE
    * possibly misspelled words in DESCRIPTION but the spelling is correct

## Downstream dependencies

Reverse dependencies checked with devtools::revdep_check(). No issues found.