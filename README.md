
<!-- README.md is generated from README.Rmd. Please edit that file -->
datavolley
==========

[![Travis-CI Build Status](https://travis-ci.org/raymondben/datavolley.svg?branch=master)](https://travis-ci.org/raymondben/datavolley)

An R package for reading DataVolley scouting files.

See also this [DataVolley file validator](https://untangl.shinyapps.io/dvalidate/), which is built on the datavolley package.

Installation
------------

``` r
library(devtools)
install_github("raymondben/datavolley")
```

Example
-------

Read the example data file bundled with the package:

``` r
library(datavolley)
x <- read_dv(system.file("extdata/example_data.dvw",package="datavolley"),insert_technical_timeouts=FALSE)
summary(x)
#> Match summary:
#> Date: 2015-01-25
#> League: Finale mladinke
#> Teams: Braslovče (JERONČIČ ZORAN/MIHALINEC DAMIJANA)
#>        vs
#>        Nova KBM Branik (HAFNER MATJAŽ/)
#> Result: 3-0 (25-16, 25-14, 25-22)
#> Duration: 67 minutes
```

Number of serves by team:

``` r
serve_idx <- find_serves(plays(x))
table(plays(x)$team[serve_idx])
#> 
#>       Braslovče Nova KBM Branik 
#>              74              54
```

Distribution of serve run lengths:

``` r
serve_run_info <- find_runs(plays(x)[serve_idx,])
table(unique(serve_run_info[,c("run_id","run_length")])$run_length)
#> 
#>  1  2  3  4  5  7  8 
#> 34 16  7  4  1  1  1
```

Heatmap of attack rate by court position:

``` r
library(ggplot2)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
## calculate attack frequency by zone, per team
attack_rate <- plays(x) %>% dplyr::filter(skill=="Attack") %>% group_by(team) %>%
    mutate(N_tm=n()) %>% group_by(team,start_zone) %>%
    summarize(rate=n()/N_tm[1]) %>% ungroup()
## add x,y coordinates associated with the zones
attack_rate <- cbind(attack_rate,ggxy(attack_rate$start_zone,end="lower"))

## for team 2, these need to be on the top half of the diagram
tm2 <- attack_rate$team==x$meta$teams$team[2]
attack_rate[tm2,c("x","y")] <- ggxy(attack_rate$start_zone,end="upper")[tm2,]
ggplot(attack_rate,aes(x,y,fill=rate))+geom_tile()+ggcourt(labels=x$meta$teams$team)+
    scale_fill_gradient2(name="Attack rate")
```

![](README-unnamed-chunk-6-1.png)

Or using arrows to show the starting and ending zones of attacks:

``` r
## tabulate attacks by starting and ending zone
attack_rate <- plays(x) %>%
    dplyr::filter(skill=="Attack" & team==x$meta$teams$team[1]) %>% ## attacks from team 1
    group_by(start_zone,end_zone) %>% summarize(rate=n()) %>% ## count attacks by start, end zone
    ungroup %>% mutate(rate=rate/sum(rate)) %>% ## convert counts to rates
    dplyr::filter(!is.na(start_zone) & !is.na(end_zone)) %>% ## drop missing-zone-info-rows
    bind_cols(ggxy(.$start_zone,end="lower",xynames=c("sx","sy"))) %>% ## start_zone x,y coords
    bind_cols(ggxy(.$end_zone,end="upper",xynames=c("ex","ey"))) %>% ## end_zone x,y coords
    arrange(desc(rate)) ## plot in reverse order so largest arrows are on the bottom

p <- ggplot(attack_rate,aes(x,y,col=rate))+ggcourt(labels=c(x$meta$teams$team[1],""))
for (n in 1:nrow(attack_rate))
  p <- p+geom_path(data=data.frame(
      x=c(attack_rate$sx[n],attack_rate$ex[n]),
      y=c(attack_rate$sy[n],attack_rate$ey[n]),
      rate=attack_rate$rate[n]),
    aes(size=rate),lineend="round",arrow=arrow(ends="last",type="closed"))
p+scale_fill_gradient(name="Attack rate")+guides(size="none")
```

![](README-unnamed-chunk-7-1.png)

Troubleshooting
---------------

If you see unexpected behaviour, try `read_dv(...,do_warn=TRUE)` to obtain more diagnostic information during the process of reading and parsing the DataVolley file. Also check the text encoding specified to `read_dv` (did you specify one??)

More
----

For more information about DataVolley, see <http://www.dataproject.com/IT/en/Volleyball>.
