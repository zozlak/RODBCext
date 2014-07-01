# RODBCext

Extension to the RODBC R package prividing support for parameterized queries.

Parameterized queries are the kosher way of executing SQL queries when query string contain data from untrusted sources (especially user input).

See [XKCD - Exploits of a Mom](http://xkcd.com/327/)

Morover parametrized queries speed up query execution if it is repeated many times (because query planning is done only once).

## Installation

At the moment RODBCext is not in CRAN and the only way is to install it from source.
To do that:

1) Obtain recent gcc, g++, and gfortran compilers. Windows users can install the
   [Rtools](http://cran.r-project.org/bin/windows/Rtools/) suite while Mac users will have to
   download the necessary tools from the [Xcode](https://itunes.apple.com/ca/app/xcode/id497799835?mt=12) suite and its
   related command line tools (found within Xcode's Preference Pane under Downloads/Components); most Linux
   distributions should already have up to date compilers (or if not they can be updated easily). 
   Windows users should include the checkbox option of installing Rtools to their path for 
   easier command line usage.

2) Install the `devtools` package (if necessary). In R, paste the following into the console:

```r
install.packages('devtools')
```

3) Load the `devtools` package (requires version 1.4+) and install from the Github source code.

```r
devtools::install_github('zozlak/RODBCext')
```

### Installing from source via git

If you are 64-bit Linux user, you won't be able to install any package using `devtools::install_github()` due to a bug in `devtools`.
In that case:

1) Obtain recent gcc, g++, and gfortran compilers (see above instructions).

2) Install the [git command line tools](http://git-scm.com/downloads).

3) Open a terminal/command-line tool. The following code will download the repository 
code to your computer, and install the package directly using R tools 
(Windows users may also have to add R and git to their 
[path](http://www.computerhope.com/issues/ch000549.htm))

```
git clone https://github.com/zozlak/RODBCext.git
R CMD INSTALL RODBCext
```

### ODBC source configuration

Altought it is not necessary, try to enable support for `SQLDescribeParam()` ODBC in your ODBC drivers.

This depends on the driver, e.g.:

- In Postgresql data sources please check if *Use Server Side Prepare* configuration option is checked (if you are unix/linux user check for line `UseServerSidePrepare = 1` in your *odbc.ini* file)

## Usage

In parameterized queries, query execution is splitted in three steps:

1. Query preparation, where database plans how to execute a query.
2. Query execution, where database actually executes a query.
   If query has parameters, they are passed in this step.
3. Fetching results (if there are any).

RODBC already has a function responsible for the 3rd step - `sqlGetResults()`, `sqlFetch()`, `sqlFetchMore()`.
RODBCext adds two functions responsible for the 1st and 2nd step:

1. `sqlPrepare()`
2. `sqlExecute()`

See examples:
```
library(RODBCext)
conn = odbcConnect("MyODBCSource")

# Run a parameterized query
sqlPrepare(conn, "SELECT * FROM table WHERE column1 = ? AND column2 = ?")
sqlExecute(conn, data=data.frame('column1value', 'column2value'))
sqlGetResults(conn)
# one-call equivalent:
sqlExecute(
  conn, 
  query="SELECT * FROM table WHERE column1 = ? AND column2 = ?", 
  data=data.frame('column1value', 'column2value'), 
  fetch=TRUE
)

# Insert many rows to a table:
sqlPrepare(conn, "INSERT INTO table (charColumn, intColumn) VALUES (?, ?)")
sqlExecute(conn, data=data.frame(c('a', 'b', 'c'), 1:3))
# one-call equivalent:
sqlExecute(
 conn, 
 query="INSERT INTO table (charColumn, intColumn) VALUES (?, ?)", 
 data=data.frame(c('a', 'b', 'c'), 1:3)
)

# Run query without parameter:
sqlPrepare(conn, "SELECT * FROM table")
sqlExecute(conn)
sqlGetResults(conn)
# one-call equivalent:
sqlExecute(conn, query="SELECT * FROM table", fetch=TRUE)

```