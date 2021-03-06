% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot.R
\name{ggcourt}
\alias{ggcourt}
\title{Add volleyball court schematic to a ggplot}
\usage{
ggcourt(court = "full", show_zones = TRUE, labels = c("Attacking team",
  "Receiving team"))
}
\arguments{
\item{court}{string: "full" (show full court) or "attack" or "defence" (show only the attacking or defending half of the court)}

\item{show_zones}{logical: add numbers indicating the court zones?}

\item{labels}{string: labels for the lower and upper court halves (pass NULL for no labels)}
}
\value{
ggplot layer
}
\description{
Add volleyball court schematic to a ggplot
}
\examples{
\dontrun{
x <- read_dv(system.file("extdata/example_data.dvw",package="datavolley"),
    insert_technical_timeouts=FALSE)

library(ggplot2)
## calculate attack frequency by zone, per team
attack_rate <- ddply(subset(plays(x),skill=="Attack"),.(team),
  function(z)ddply(z,.(start_zone),function(w)data.frame(rate=nrow(w)/nrow(z))))
## add x,y coordinates associated with the zones
attack_rate <- cbind(attack_rate,ggxy(attack_rate$start_zone,end="lower"))
## for team 2, these need to be on the top half of the diagram
tm2 <- attack_rate$team==x$meta$teams$team[2]
attack_rate[tm2,c("x","y")] <- ggxy(attack_rate$start_zone,end="upper")[tm2,]
ggplot(attack_rate,aes(x,y,fill=rate))+geom_tile()+ggcourt(labels=x$meta$teams$team)+
  scale_fill_gradient2(name="Attack rate")

## show map of starting and ending zones of attacks using arrows
## tabulate attacks by starting and ending zone
attack_rate <- as.data.frame(xtabs(~start_zone+end_zone,
  data=subset(plays(x),skill=="Attack" & team==x$meta$teams$team[1],
  stringsAsFactors=FALSE)
attack_rate$start_zone <- as.numeric(attack_rate$start_zone)
attack_rate$end_zone <- as.numeric(attack_rate$end_zone)
attack_rate$rate <- attack_rate$Freq/sum(attack_rate$Freq)
attack_rate <- attack_rate[attack_rate$Freq>0,]
## starting x,y coordinates
attack_rate <- cbind(attack_rate,ggxy(attack_rate$start_zone,end="lower",xynames=c("sx","sy")))
## ending x,y coordinates
attack_rate <- cbind(attack_rate,ggxy(attack_rate$end_zone,end="upper",xynames=c("ex","ey")))
## plot in reverse order so largest arrows are on the bottom
attack_rate <- attack_rate[order(attack_rate$rate,decreasing=TRUE),]
p <- ggplot(attack_rate,aes(x,y,col=rate))+ggcourt(labels=c(x$meta$teams$team[1],""))
for (n in 1:nrow(attack_rate))
    p <- p+geom_path(data=data.frame(
            x=c(attack_rate$sx[n],attack_rate$ex[n]),
            y=c(attack_rate$sy[n],attack_rate$ey[n]),
            rate=attack_rate$rate[n]),
        aes(size=rate),lineend="round",arrow=arrow(ends="last",type="closed"))
p+scale_fill_gradient(name="Attack rate")+guides(size="none")
}
}
\seealso{
\code{\link{ggxy}}
}
