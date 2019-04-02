#pull in teaming parameters for retention model
setwd("//g-filesvr/users$/coxjil/My Documents/Jill Test/Retention/")
# getwd()

library(RODBC)
# library(plotly)
library(ggplot2)
library(dplyr)
library(data.table)
library(reshape2)
library(stringr)
library(rjson)
library(robustHD)

options(scipen=999) # large positive value makes use of scientific notation less likely

# Give the input file name to the function.
secrets <- as.data.frame(fromJSON(file = "secrets.json"))

# below is done so that passwords are not uploaded to bitbucket
secrets_for_LIVE_sqlquery <- sprintf("driver={SQL Server};server=SQLAAG02;database=LIVE;uid=%s;pwd=%s", secrets$username, 
                                    secrets$password)
dbhandle_LIVE <- odbcDriverConnect(secrets_for_LIVE_sqlquery)

secrets_for_O <- sprintf("driver={SQL Server};server=SQLAAG02;database=O;uid=%s;pwd=%s", secrets$username, secrets$password)
dbhandle_O <- odbcDriverConnect(secrets_for_O)

secrets_for_S <- sprintf("driver={SQL Server};server=CTG-SQLAAG02;database=S;uid=%s;pwd=%s", secrets$username, secrets$password)
dbhandle_S <- odbcDriverConnect(secrets_for_S)


# need to have everything work within the same date. Those dates will be reference throughout, so first step is to find the min and max leg number for the given time period analyzed

################################################################
# Variable (starts with var_) data values can be entered below #
################################################################
# date range values
var_startdate <- as.vector(as.character('2017-8-1')) 
var_enddate <- as.vector(as.character('2018-1-31'))

##############################################################################################
# builds historical manpower profile below
##############################################################################################

string_for_sqlquery3 <- sprintf("select ord_hdrnumber, lgh_number, lgh_driver1, lgh_driver2, lgh_startdate, lgh_enddate,  
                                lgh_class1, trc_division, lgh_startcity, lgh_endcity   
                                from LIVE.dbo.legheader with (nolock) 
                                where lgh_startdate >= dateadd(dd, -0, '%s') and cast(lgh_startdate as date) <= dateadd(dd, 0, '%s') 
                                and lgh_class1 != 'SOLU'   
                                order by lgh_tractor", var_startdate, var_enddate)
# had to cast as date end because it assumes hh:mm:ss as 00:00:00, so no end date will be seen, but will see all for after start
string_for_sqlquery3 <- str_replace_all(string_for_sqlquery3, "[\r\n]", " ")

# not needed now: lgh_odometerstart, lgh_odometerend, lgh_class1, trc_division,

mpp_hist_df <- sqlQuery(dbhandle_LIVE, (string_for_sqlquery3), as.is = TRUE)

mpp_hist_df <- mpp_hist_df[!is.na(mpp_hist_df$ord_hdrnumber),] # just in case there are NAs
mpp_hist_df <- mpp_hist_df[!is.na(mpp_hist_df$lgh_number),] # just in case there are NAs
mpp_hist_df$ord_hdrnumber <- as.character(trimws(mpp_hist_df$ord_hdrnumber))
mpp_hist_df$lgh_number <- as.character(trimws(mpp_hist_df$lgh_number))

mpp_hist_df$lgh_startdate <- as.POSIXct(mpp_hist_df$lgh_startdate, origin='1970-01-01', tz="UTC")
mpp_hist_df$lgh_enddate <- as.POSIXct(mpp_hist_df$lgh_enddate, origin='1970-01-01', tz="UTC")
# https://stackoverflow.com/questions/30038701/r-as-posixct-dropping-hours-minutes-and-seconds

#mpp_hist_df$VehID <- as.character(trimws(mpp_hist_df$VehID))
#mpp_hist_df$trc_division <- as.character(trimws(mpp_hist_df$trc_division))
mpp_hist_df$lgh_class1 <- as.character(trimws(mpp_hist_df$lgh_class1))
# starting as character so that I can use substring to replace improper NAs about 15 lines below. Willc onvert to factor after

#mpp_hist_df$DriverID <- as.character(trimws(mpp_hist_df$DriverID))
mpp_hist_df$lgh_driver1 <- as.character(trimws(mpp_hist_df$lgh_driver1))
mpp_hist_df$lgh_driver2 <- as.character(trimws(mpp_hist_df$lgh_driver2))

#mpp_hist_df$lgh_odometerstart <- as.numeric(trimws(mpp_hist_df$lgh_odometerstart))
#mpp_hist_df$lgh_odometerend <- as.numeric(trimws(mpp_hist_df$lgh_odometerend))
mpp_hist_df$lgh_startcity <- as.character(trimws(mpp_hist_df$lgh_startcity))
mpp_hist_df$lgh_endcity <- as.character(trimws(mpp_hist_df$lgh_endcity))

mpp_hist_df <- mpp_hist_df[which(grepl("UNK", mpp_hist_df$lgh_driver1 ) != TRUE),] # 24435 to 20223
# mpp_hist_df <- mpp_hist_df[which(grepl("UNK", mpp_hist_df$VehID ) != TRUE),] # 20223 to 20223 

# mpp_hist_df$mpp_teamleader <- as.character(trimws(mpp_hist_df$mpp_teamleader))
# mpp_hist_df$mpp_fleet <- as.character(trimws(mpp_hist_df$mpp_fleet))
mpp_hist_df$trc_division <- as.character(trimws(mpp_hist_df$trc_division))
# mpp_hist_df$trc_fleet <- as.character(trimws(mpp_hist_df$trc_fleet))


################################################################################################
#import city data - needed to adjust timezones to GMT / UTC ####################################
################################################################################################

city_df <- sqlQuery(dbhandle_LIVE, "select cty_code, cty_zip, cty_GMTDelta from TMW_LIVE.dbo.city with (nolock) ")

city_df$cty_code <- as.character(city_df$cty_code)
city_df$cty_zip <- as.character(city_df$cty_zip)
city_df$cty_GMTDelta <- as.integer(city_df$cty_GMTDelta)
# head(city_df)
# str(city_df)

# need to merge with start and end by cty_code to adjust each to GMT
city_df$lgh_startcity <- city_df$cty_code
city_df$lgh_endcity <- city_df$cty_code

city_df$lgh_start_cty_GMTDelta <- city_df$cty_GMTDelta
city_df$lgh_end_cty_GMTDelta <- city_df$cty_GMTDelta

lgh_start_city_df <- city_df[,c("lgh_startcity", "lgh_start_cty_GMTDelta")]
lgh_end_city_df <- city_df[,c("lgh_endcity", "lgh_end_cty_GMTDelta")]
# need to merge to get cty_GMTDeta to adjust for timezones. 

# merge in GMTdelta and then calculate UTC adjusted times, use that to calculate time for lgh time
mpp_hist_df <- inner_join(mpp_hist_df, lgh_start_city_df, by = "lgh_startcity") 
mpp_hist_df <- inner_join(mpp_hist_df, lgh_end_city_df, by = "lgh_endcity") 

mpp_hist_df$lgh_startdateGMT <- as.POSIXct((mpp_hist_df$lgh_startdate + (mpp_hist_df$lgh_start_cty_GMTDelta*60*60)), 
                                           origin="1970-01-01", tz="UTC") 
mpp_hist_df$lgh_enddateGMT <- as.POSIXct((mpp_hist_df$lgh_enddate + (mpp_hist_df$lgh_end_cty_GMTDelta*60*60)), origin="1970-01-01",
                                         tz="UTC")  

# for cut off dates need east coast time
mpp_hist_df$lgh_startdateEST <- as.POSIXct((mpp_hist_df$lgh_startdate - (4*60*60) + (mpp_hist_df$lgh_start_cty_GMTDelta*60*60)),
                                           origin="1970-01-01", tz="UTC") 
mpp_hist_df$lgh_enddateEST <- as.POSIXct((mpp_hist_df$lgh_enddate - (4*60*60) + (mpp_hist_df$lgh_end_cty_GMTDelta*60*60)), 
                                         origin="1970-01-01", tz="UTC") 

#leg in hours below
# mpp_hist_df$lgh_hours <- as.numeric((difftime(mpp_hist_df$lgh_enddateGMT, mpp_hist_df$lgh_startdateGMT, tz="UTC", units = "mins"))/(60))

mpp_hist_df <- mpp_hist_df[,c("ord_hdrnumber", "lgh_number",  "lgh_driver1", "lgh_driver2", "lgh_startdateEST", "lgh_enddateEST", 
                              "lgh_class1",  "trc_division")] 


###############
# how many legs 
mpp_hist_df_leg_count <- mpp_hist_df %>% group_by(lgh_driver1, lgh_driver2) %>% summarise(leg_count=n())


mpp_hist_df <- inner_join(mpp_hist_df,mpp_hist_df_leg_count,by = c("lgh_driver1", "lgh_driver2"))

# for the times between the first and last time there is a driver change, including UNK
 mpp_hist_df_try <- mpp_hist_df[order(mpp_hist_df$lgh_driver1, mpp_hist_df$lgh_driver2, mpp_hist_df$lgh_startdate),] 

# need to have all drivers on the same playing field
# so have drivers switch columns and then restack then run
mpp_hist_df_to_append <- mpp_hist_df
# this swaps columns
mpp_hist_df_to_append[, c("lgh_driver2", "lgh_driver1")] <- mpp_hist_df_to_append[, c("lgh_driver1", "lgh_driver2")]

mpp_hist_df_total <- rbind(mpp_hist_df,mpp_hist_df_to_append)

mpp_hist_df_concise <- mpp_hist_df_total %>% group_by(lgh_driver1, lgh_driver2) %>%
  arrange(lgh_driver1, lgh_driver2, lgh_startdateEST) %>% 
  filter(row_number() == 1)
# filter(row_number() %in% c(1, n())) # keeps the first and last by each group

# note all done form lgh_driver1's perspective - note columns were switched to make sure every driver on every leg for the time 
# period analyzed was classified as lgh_driver1
mpp_hist_df_concise$DriverID <- mpp_hist_df_concise$lgh_driver1 
mpp_hist_df_concise <- mpp_hist_df_concise[mpp_hist_df_concise$DriverID != 'UNKNOWN',]
mpp_hist_df_concise$team_binary <- ifelse(mpp_hist_df_concise$lgh_driver2 == 'UNKNOWN', 0, 1)

mpp_hist_df_concise <- mpp_hist_df_concise[,c("DriverID", "team_binary", "leg_count", "lgh_enddateEST")]

#export table
#write.csv(mpp_hist_df_concise, "teaming.csv")

#export to a sql table
dbhandle_CIP <- odbcDriverConnect('driver={SQL Server};server=SQLAAG02;database=CIP;coxjil;pwd=s;trusted_connection=yes')
sqlSave(dbhandle_CIP, mpp_hist_df_concise, tablename='teaming')
#append existing table
#sqlQuery(dbhandle_CIP, 'insert into practiceR select * from datecycle')

