#' Additional validation checks on a DataVolley file
#'
#' This function is automatically run as part of \code{read_dv} if \code{extra_validation} is greater than zero.
#' The current validation messages/checks are:
#' \itemize{
#'   \item message "The listed player is not on court in this rotation": the player making the action is not part of the current rotation. Libero players are ignored for this check
#'   \item message "Player making a front row attack is in the back row": an attack starting from zones 2-4 was made by a player in the back row of the current rotation
#'   \item message "Attack (which was blocked) does not have number of blockers recorded"
#'   \item message "Attack (which was followed by a block) has 'No block' recorded for number of players"
#'   \item message "Repeated row with same skill and evaluation_code for the same player"
#'   \item message "Point awarded to incorrect team following error (or \"error\" evaluation incorrect)"
#'   \item message "Point awarded to incorrect team (or [winning play] evaluation incorrect)"
#'   \item message "Scores do not follow proper sequence": one or both team scores change by more than one point at a time
#'   \item message "Visiting/Home team rotation has changed incorrectly"
#'   \item message "Player lineup did not change after substitution: was the sub recorded incorrectly?"
#'   \item message "Player lineup conflicts with recorded substitution: was the sub recorded incorrectly?"
#'   \item message "Reception was not preceded by a serve": a recorded reception was not immediately preceded by a serve
#'   \item message "Reception type does not match serve type": the type of reception (e.g. "Jump-float serve reception" does not match the serve type (e.g. "Jump-float serve")
#'   \item message "Reception start zone does not match serve start zone"
#'   \item message "Reception end zone does not match serve end zone"
#'   \item message "Reception end sub-zone does not match serve end sub-zone"
#'   \item message "Attack type ([type]) does not match set type ([type])": the type of attack (e.g. "Head ball attack") does not match the set type (e.g. "High ball set")
#'   \item message "Block type ([type]) does not match attack type ([type])": the type of block (e.g. "Head ball block") does not match the attack type (e.g. "High ball attack")
#'   \item message "Dig type ([type]) does not match attack type ([type])": the type of dig (e.g. "Head ball dig") does not match the attack type (e.g. "High ball attack")
#' }
#' 
#' @param x datavolley: datavolley object as returned by \code{read_dv}
#' @param validation_level numeric: how strictly to check? If 0, perform no checking; if 1, only identify major errors; if 2, also return any issues that are likely to lead to misinterpretation of data; if 3, return all issues (including minor issues such as those that might have resulted from selective post-processing of compound codes.
#'
#' @return data.frame with columns message (the validation message), file_line_number (the corresponding line number in the DataVolley file), and file_line (the actual line from the DataVolley file).
#'
#' @seealso \code{\link{read_dv}}
#'
#' @examples
#' \dontrun{
#'   x <- read_dv(system.file("extdata/example_data.dvw",package="datavolley"),
#'     insert_technical_timeouts=FALSE)
#'   xv <- validate_dv(x)
#' }
#'
#' @export
validate_dv <- function(x,validation_level=2) {
    assert_that(is.numeric(validation_level) && validation_level %in% 0:3)
    
    out <- data.frame(file_line_number=integer(),message=character(),file_line=character(),severity=numeric(),stringsAsFactors=FALSE)
    chk_df <- function(chk,msg,severity=2) data.frame(file_line_number=chk$file_line_number,message=msg,file_line=x$raw[chk$file_line_number],severity=severity,stringsAsFactors=FALSE)
    if (validation_level<1) return(out)

    plays <- plays(x)
    
    ## receive type must match serve type
    idx <- which(plays$skill %eq% "Reception")
    idx2 <- idx[!plays$skill[idx-1] %eq% "Serve"]
    if (length(idx2)>0) {
        out <- rbind(out,chk_df(plays[idx2,],"Reception was not preceded by a serve",severity=3))
        idx <- idx[plays$skill[idx-1] %eq% "Serve"]
    }
    idx2 <- idx[plays$skill_type[idx]!=paste0(plays$skill_type[idx-1]," reception") & (plays$skill_type[idx]!="Unknown serve reception type" & plays$skill_type[idx-1]!="Unknown serve type")]
    if (length(idx2)>0)
        out <- rbind(out,chk_df(plays[idx2,],paste0("Reception type (",plays$skill_type[idx2],") does not match serve type (",plays$skill_type[idx2-1],")")))
    if (validation_level>2) {
        ## reception zones must match serve zones
        ## start zones mismatch, but not any missing
        idx2 <- idx[(!plays$start_zone[idx] %eq% plays$start_zone[idx-1]) & !is.na(plays$start_zone[idx]) & !is.na(plays$start_zone[idx-1])]
        if (length(idx2)>0)
            out <- rbind(out,chk_df(plays[idx2,],paste0("Reception start zone (",plays$start_zone[idx2],") does not match serve start zone (",plays$start_zone[idx2-1],")"),severity=1))
        ## end zones mismatch, but not any missing
        idx2 <- idx[(!plays$end_zone[idx] %eq% plays$end_zone[idx-1]) & !is.na(plays$end_zone[idx]) & !is.na(plays$end_zone[idx-1])]
        if (length(idx2)>0)
            out <- rbind(out,chk_df(plays[idx2,],paste0("Reception end zone (",plays$end_zone[idx2],") does not match serve end zone (",plays$end_zone[idx2-1],")"),severity=1))
        ## end zones mismatch, but not any missing
        idx2 <- idx[(!plays$end_subzone[idx] %eq% plays$end_subzone[idx-1]) & !is.na(plays$end_subzone[idx]) & !is.na(plays$end_subzone[idx-1])]
        if (length(idx2)>0)
            out <- rbind(out,chk_df(plays[idx2,],paste0("Reception end sub-zone (",plays$end_subzone[idx2],") does not match serve end sub-zone (",plays$end_subzone[idx2-1],")"),severity=1))
    
        ## attack type must match set type
        idx <- which(plays$skill %eq% "Attack")
        idx <- idx[plays$skill[idx-1] %eq% "Set"]
        idx <- idx[plays$skill_type[idx]!=gsub(" set"," attack",plays$skill_type[idx-1])]
        if (length(idx)>0)
            out <- rbind(out,chk_df(plays[idx,],paste0("Attack type (",plays$skill_type[idx],") does not match set type (",plays$skill_type[idx-1],")")))

        ## block type must match attack type
        idx <- which(plays$skill %eq% "Block")
        idx <- idx[plays$skill[idx-1] %eq% "Attack"]
        idx <- idx[plays$skill_type[idx]!=gsub(" attack"," block",plays$skill_type[idx-1])]
        if (length(idx)>0)
            out <- rbind(out,chk_df(plays[idx,],paste0("Block type (",plays$skill_type[idx],") does not match attack type (",plays$skill_type[idx-1],")")))

        ## dig type must match attack type
        idx <- which(plays$skill %eq% "Dig")
        idx <- idx[plays$skill[idx-1] %eq% "Attack"]
        idx <- idx[plays$skill_type[idx]!=gsub(" attack"," dig",plays$skill_type[idx-1])]
        if (length(idx)>0)
            out <- rbind(out,chk_df(plays[idx,],paste0("Dig type (",plays$skill_type[idx],") does not match attack type (",plays$skill_type[idx-1],")")))
    }
    
    ## front-row attacking player isn't actually in front row
    ## find front-row players for each attack
    attacks <- plays[plays$skill %eq% "Attack",]
    for (p in 1:6) attacks[,paste0("attacker_",p)] <- NA
    idx <- attacks$home_team==attacks$team
    attacks[idx,paste0("attacker_",1:6)] <- attacks[idx,paste0("home_p",1:6)]
    attacks[!idx,paste0("attacker_",1:6)] <- attacks[!idx,paste0("visiting_p",1:6)]
    chk <- attacks[attacks$start_zone %in% c(2,3,4) & (attacks$player_number==attacks$attacker_1 | attacks$player_number==attacks$attacker_5 | attacks$player_number==attacks$attacker_6),]
    if (nrow(chk)>0)
        out <- rbind(out,chk_df(chk,"Player making a front row attack is in the back row",severity=3))

    ## number of blockers (for an attack) should be >=1 if it is followed by a block
    idx <- which(plays$skill %eq% "Block")-1 ## -1 to be on the attack
    idx2 <- idx[plays$skill[idx] %eq% "Attack" & (!plays$team[idx] %eq% plays$team[idx+1]) & is.na(plays$num_players[idx])]
    if (length(idx2)>0)
        out <- rbind(out,chk_df(plays[idx2,],"Attack (which was blocked) does not have number of blockers recorded",severity=1))

    idx2 <- idx[plays$skill[idx] %eq% "Attack" & (!plays$team[idx] %eq% plays$team[idx+1]) & (plays$num_players[idx] %eq% "No block")]
    if (length(idx2)>0)
        out <- rbind(out,chk_df(plays[idx2,],"Attack (which was followed by a block) has \"No block\" recorded for number of players",severity=3))

    ## player not in recorded rotation making a play (other than by libero)
    liberos_v <- x$meta$players_v$number[grepl("L",x$meta$players_v$special_role)] ##subset(x$meta$players_v,grepl("L",special_role))$number
    liberos_h <- x$meta$players_h$number[grepl("L",x$meta$players_h$special_role)] ##subset(x$meta$players_h,grepl("L",special_role))$number
    pp <- plays[plays$skill %in% c("Serve","Attack","Block","Dig","Freeball","Reception","Set"),]
    pp$labelh <- "home_team"
    pp$labelv <- "visiting_team"
    temp <- ldply(1:nrow(pp),function(z) {fcols <- if (pp$home_team[z] %eq% pp$team[z]) c("home_p1","home_p2","home_p3","home_p4","home_p5","home_p6","labelh") else c("visiting_p1","visiting_p2","visiting_p3","visiting_p4","visiting_p5","visiting_p6","labelv"); out <- pp[z,fcols]; names(out) <- c(paste0("player",1:6),"which_team"); out })
    chk <- sapply(1:nrow(pp),function(z) !pp$player_number[z] %in% (if (temp$which_team[z]=="home_team") liberos_h else liberos_v) & (!pp$player_number[z] %in% temp[z,]))
    if (any(chk))
        out <- rbind(out,data.frame(file_line_number=pp$file_line_number[chk],message="The listed player is not on court in this rotation",file_line=x$raw[pp$file_line_number[chk]],severity=3,stringsAsFactors=FALSE))

    ## duplicate entries with same skill and evaluation code for the same player
    idx <- which((plays$evaluation_code[-1] %eq% plays$evaluation_code[-nrow(plays)]) &
                 (plays$skill[-1] %eq% plays$skill[-nrow(plays)]) &
                 (plays$team[-1] %eq% plays$team[-nrow(plays)]) &
                 (plays$player_number[-1] %eq% plays$player_number[-nrow(plays)])
                 )+1
    if (length(idx)>0)
        out <- rbind(out,data.frame(file_line_number=plays$file_line_number[idx],message="Repeated row with same skill and evaluation_code for the same player",file_line=x$raw[plays$file_line_number[idx]],severity=3,stringsAsFactors=FALSE))
    
    ## point not awarded to right team following error
    chk <- (plays$evaluation_code %eq% "=" | (plays$skill %eq% "Block" & plays$evaluation_code %eq% "/")) &  ## error or block Invasion
            (plays$team %eq% plays$point_won_by)
    if (any(chk))
        out <- rbind(out,data.frame(file_line_number=plays$file_line_number[chk],message="Point awarded to incorrect team following error (or \"error\" evaluation incorrect)",file_line=x$raw[plays$file_line_number[chk]],severity=3,stringsAsFactors=FALSE))
    
    ## point not awarded to right team following win
    chk <- (plays$skill %in% c("Serve","Attack","Block") & plays$evaluation_code %eq% "#") &  ## ace or winning attack or block
            (!plays$team %eq% plays$point_won_by)
    if (any(chk))
        out <- rbind(out,data.frame(file_line_number=plays$file_line_number[chk],message=paste0("Point awarded to incorrect team (or \"",plays$evaluation[chk],"\" evaluation incorrect)"),file_line=x$raw[plays$file_line_number[chk]],severity=3,stringsAsFactors=FALSE))

    ## scores not in proper sequence
    ## a team's score should never increase by more than 1 at a time. May be negative (change of sets)
    temp <- plays[,c("home_team_score","visiting_team_score","set_number")]
    temp <- apply(temp,2,diff)
    ## either score increases by more than one, or (decreases and not end of set)
    chk <- which((temp[,1]>1 | temp[,2]>1) | ((temp[,1]<0 | temp[,2]<0) & !(is.na(temp[,3]) | temp[,3]>0)))
    ##chk <- diff(plays$home_team_score)>1 | diff(plays$visiting_team_score)>1
    ##if (any(chk))
    if (length(chk)>0)
        out <- rbind(out,data.frame(file_line_number=plays$file_line_number[chk],message="Scores do not follow proper sequence (note that the error may be in the point after this one)",file_line=x$raw[plays$file_line_number[chk]],severity=3,stringsAsFactors=FALSE))

    ## check for incorrect rotation changes
    rotleft <- function(x) if (is.data.frame(x)) {out <- cbind(x[,-1],x[,1]); names(out) <- names(x); out} else c(x[-1],x[1])
    isrotleft <- function(x,y) all(as.numeric(rotleft(x))==as.numeric(y)) ## is y a left-rotated version of x?
    for (tm in c("*","a")) {
        rot_cols <- if (tm=="a") paste0("visiting_p",1:6) else paste0("home_p",1:6)
        temp <- plays[!tolower(plays$skill) %eq% "technical timeout",]
        rx <- temp[,rot_cols]
        idx <- unname(c(FALSE,rowSums(abs(apply(rx,2,diff)))>0)) ## rows where rotation changed from previous
        idx[is.na(idx)] <- FALSE ## end of set, etc, ignore
        idx[temp$substitution] <- FALSE ## subs, ignore these here and they will be checked in the next section
        for (k in which(idx)) {
            if (!isrotleft(rx[k-1,],rx[k,]))
                out <- rbind(out,data.frame(file_line_number=temp$file_line_number[k],message=paste0(if (tm=="a") "Visiting" else "Home"," team rotation has changed incorrectly"),file_line=x$raw[temp$file_line_number[k]],severity=3,stringsAsFactors=FALSE))
        }
    }
    
    ## check that players changed correctly on substitution
    ## e.g. *c02:01 means player 2 replaced by player 1
    idx <- which(plays$substitution & grepl("^.c",plays$code))
    idx <- idx[idx>2 & idx<(nrow(plays)-1)] ## discard anything at the start or end of the file
    rot_errors <- list()
    for (k in idx) {
        rot_cols <- if (grepl("^a",plays$code[k])) paste0("visiting_p",1:6) else paste0("home_p",1:6)
        prev_rot <- plays[k-1,rot_cols]
        if (any(is.na(prev_rot))) {
            if (k>2) prev_rot <- plays[k-2,rot_cols]
        }
        if (any(is.na(prev_rot))) next ## could perhaps search further backwards, but should not need to
        ## have only seen one NA rot row in sequence in files so far
        
        new_rot <- plays[k+1,rot_cols]
        if (any(is.na(new_rot))) {
            if (k<(nrow(plays)-2)) new_rot <- plays[k+2,rot_cols]
        }
        if (any(is.na(new_rot))) next
        
        if (all(new_rot==prev_rot)) {
            ## players did not change
            rot_errors[[length(rot_errors)+1]] <- data.frame(file_line_number=plays$file_line_number[k],message=paste0("player lineup did not change after substitution: was the sub recorded incorrectly?"),file_line=x$raw[plays$file_line_number[k]],severity=3,stringsAsFactors=FALSE)
            next
        }
        sub_out <- as.numeric(sub(":.*$","",sub("^.c","",plays$code[k]))) ## outgoing player
        sub_in <- as.numeric(sub("^.*:","",plays$code[k])) ## incoming player
        if (!sub_out %in% prev_rot || !sub_in %in% new_rot || sub_in %in% prev_rot || sub_out %in% new_rot) {
            rot_errors[[length(rot_errors)+1]] <- data.frame(file_line_number=plays$file_line_number[k],message=paste0("Player lineup conflicts with recorded substitution: was the sub recorded incorrectly?"),file_line=x$raw[plays$file_line_number[k]],severity=3,stringsAsFactors=FALSE)
            next
        }
    }
    if (length(rot_errors)>0) out <- rbind(out,do.call(rbind,rot_errors))
    out <- out[4-out$severity<=validation_level,]
    out[,setdiff(names(out),"severity")]
}
