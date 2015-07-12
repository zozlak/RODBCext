## Test environments
* local Linux install, x64, R 3.2.0
* devtools win-builder, R unstable r68646

## R CMD check results
There were no ERRORs nor WARNINGs.
Local Linux build generated no NOTEs.
Win-builder generated 2 NOTEs:
- on possibly misspelled words in DESCRIPTION, but the spelling is correct
- "No repository set, so cyclic dependency check skipped" NOTE, but as RODBCext has no downstream dependencies and this NOTE was not rised during the local build, this should not be an issue

## Downstream dependencies
According to CRAN there are no downstream dependencies.