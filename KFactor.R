# Determine K-Factor at a SALI Site that has the necessary data ###
# Version 1.2 - 07/05/2021 - Treating weak structure same as massive structure
# Version 1.1 - 14/04/2021 - Adjusted soil structure to include all available structure types in SALI as well as treating polyhedral structure similar to granular structure.
# Version 1 - 10/10/2017 - Original script
#
# Step 1 - Run sql "KFactorDataExtraction.sql" creating file "KFData.csv"
# Step 2 - Run ProcessPSAData.R (Require predicted Clay, Silt, CS, FS for project area)
# Step 3 - Place Clay_average.tif and other _average.tifs from Step 2 into Kfactor directory 
# Step 3 - Run this script "KFactor.R" creating file "K.csv"
#
# Script starts here

setwd("M:/Projects/Logan_Albert_SEQW/Modelling/SiteData/Kfactor")
soil.data<-read.table("KFdata.csv",header=TRUE,sep=",") #read all the data in
library(plyr)
library(raster)
library(sp)

#pivot data
library(reshape)
a<-cast(soil.data, PROJECT_CODE + SITE_ID + OBS_NO + HORIZON_NO + SAMPLE_NO + UD + LD + X + Y + GRADE + SIZ + TYPE + COMPOUND_PEDALITY + PERMEABILITY ~ ATTRIBUTE, value = "VALUE", fun.aggregate=mean)

#get interpolated particle size info at SALI sites (NOTE: Need to run ProcessPSAData.R script first)

psa <- stack("Clay_average.tif", "CS_average.tif", "FS_average.tif", "Silt_average.tif") #get raster data
d <- na.omit(unique(subset(a, select = c('PROJECT_CODE', 'SITE_ID', 'OBS_NO', 'X', 'Y')))) #get points
s <- SpatialPoints(data.frame(d$X,d$Y)) #convert points df to spatial points object
psas <- extract(psa, s, method='simple', buffer=NULL, small=FALSE, cellnumbers=FALSE, fun=NULL, na.rm=TRUE, nl = 4, df=TRUE, factors=FALSE, sp=TRUE)
psadata <- unique(as.data.frame(psas)) #Convert results from a Spatialpoints object back to a df and remove duplicates
psadata <- rename(psadata, c(d.X = "X", d.Y = "Y"))

#Merge interpolated with lab data
a <- join(a, psadata, by = c("X", "Y"), type = "left", match = "first") #Merge interpolated psa data to original sample results

#Particle size (M) (Brown book)
a$M <- (a$Silt + (0.7*a$FS))*(100-a$Clay)
a$MInt <- (a$Silt_average + (0.7*a$FS_average))*(100-a$Clay_average)

#Particle size (M) (ASRIS)
a$P125 <- (a$Clay+ a$Silt + (0.7*a$FS))*(100*exp(-0.019*a$Clay))
a$P125Int <- (a$Clay_average + a$Silt_average + (0.7*a$FS_average))*(100*exp(-0.019*a$Clay_average))

#Organic matter
OM <- unique(na.omit(subset(a, select = c("PROJECT_CODE", "SITE_ID", "OBS_NO", "HORIZON_NO", "SAMPLE_NO", "UD", "LD", "WB_OC"))))
OM$OM <- 1.72*OM$WB_OC #Apply OM conversion factor (1.72) as described in Brown Book p.365 
OM <- aggregate(x = OM$OM, by = list(PROJECT_CODE = OM$PROJECT_CODE, SITE_ID = OM$SITE_ID), FUN = "mean") #Avearge OM accross available sample depths if sites have >1 OM value
OM <- rename(OM, c(x = "OM")) #rename column name from 'x' to 'OM'
OM$OM[OM$OM > 4] <- 4 #Change OM values > 4% to 4% based on Brown Book conclusion p.363
a <- join(a, OM, by = c("PROJECT_CODE", "SITE_ID"), type = "left", match = "first") #Join adjusted avearge OM values to orginal sample results

#Soil Structure (SS)
a$SS[a$GRADE == "W"] <- 4 #Treating W same as massive, added 7/5/21
a$SS[a$SIZ == 1 & a$TYPE == "GR"] <- 1 # Changed from SS == 2 to 1 (12/04/2021)
a$SS[a$SIZ == 2 & a$TYPE %in% c("GR", "PO")] <- 2 #Added PO and changed SS from 3 to 2 for a more even spread (12/04/2021)
a$SS[a$SIZ == 3 & a$TYPE %in% c("GR", "PO")] <- 3 #Added PO (12/04/2021)
a$SS[a$GRADE == "V"] <- 4
a$SS[a$TYPE %in% c("PL", "SB", "CA", "AB", "BL", "PO", "LE", "CO", "PR")] <- 4 #Added BL, CA, PO, LE and PR (12/04/2021)     

#Profile permeability class (PP) standard
a$PP[a$PERMEABILITY == 4] <- 2 #Added (12/04/2021)
a$PP[a$PERMEABILITY == 3] <- 4
a$PP[a$PERMEABILITY == 2] <- 5
a$PP[a$PERMEABILITY == 1] <- 6

#Adjustment of a$PP according to the mentioned qualifiers in Cresswell 1993 for the LASER Mod area sites
# Change PP class from 4 to 3 where the subsoil structure grade is moderate or strong (Cresswell 1993)
a$PP <- ifelse(a$PROJECT_CODE == "BNH" & a$SITE_ID == 16, 3, a$PP) 
a$PP <- ifelse(a$PROJECT_CODE == "BNH" & a$SITE_ID == 417, 3, a$PP)
a$PP <- ifelse(a$PROJECT_CODE == "GCCC" & a$SITE_ID == 20, 3, a$PP)
a$PP <- ifelse(a$PROJECT_CODE == "KAL" & a$SITE_ID == 6001, 3, a$PP)
a$PP <- ifelse(a$PROJECT_CODE == "LASER" & a$SITE_ID == 58, 3, a$PP)
a$PP <- ifelse(a$PROJECT_CODE == "SEQ" & a$SITE_ID == 13, 3, a$PP)
a$PP <- ifelse(a$PROJECT_CODE == "SOC" & a$SITE_ID == 11, 3, a$PP)
# Change PP class to 6 if soil shallow
a$PP <- ifelse(a$PROJECT_CODE == "LASER" & a$SITE_ID == 103, 6, a$PP)
a$PP <- ifelse(a$PROJECT_CODE == "LASER" & a$SITE_ID == 109, 6, a$PP)
# Change PP class to 5 if subsoil a massive or weakly structured clay
a$PP <- ifelse(a$PROJECT_CODE == "SEQ" & a$SITE_ID == 20, 5, a$PP)

#K-Factor (RUSLE - Brown Book) Equation 28.2
a$K <- (2.766*(a$M^1.14)*(10^-7)*(12-a$OM))+(4.28*(10^-3)*(a$SS-2))+(3.28*(10^-3)*(a$PP-3))
a$KInt <- (2.766*(a$MInt^1.14)*(10^-7)*(12-a$OM))+(4.28*(10^-3)*(a$SS-2))+(3.28*(10^-3)*(a$PP-3))

#K-Factor (ASRIS)
a$RAW <- (2.77*(10^-7)*(a$P125^1.14)*(12-a$OM))+(4.28*(10^-3)*(a$SS-2))+(3.29*(10^-3)*(a$PP-3))
a$RAWInt <- (2.77*(10^-7)*(a$P125Int^1.14)*(12-a$OM))+(4.28*(10^-3)*(a$SS-2))+(3.29*(10^-3)*(a$PP-3))
a$ADJ <- a$RAW/(1.462+(0.048*(1.03259^(a$FS+a$CS)))-1)
a$ADJInt <- a$RAWInt/(1.462+(0.048*(1.03259^(a$FS_average+a$CS_average)))-1)

#Prepare data for Cubist (Brown Book)
result <- subset(a, !is.na(K)) #list of sites without nulls in K Factor
result <- aggregate(x = result$K, by = list(PROJECT_CODE = result$PROJECT_CODE, SITE_ID = result$SITE_ID), FUN = "mean")
resultNA <- subset(a, is.na(K)) #list of sites with nulls in K Factor
resultNA <- subset(resultNA, select = c("PROJECT_CODE", "SITE_ID", "KInt")) #Get K value calculated using interpolated PSA
resultNA <- rename(resultNA, c(KInt = "K")) #Rename KInt column to K for sites without real PSA
resultNA <- aggregate(x = resultNA$K, by = list(PROJECT_CODE = resultNA$PROJECT_CODE, SITE_ID = resultNA$SITE_ID), FUN = "mean")
AllResults = merge (result, resultNA, by = c("PROJECT_CODE", "SITE_ID"), all.y = TRUE)
AllResults = subset(AllResults, is.na(x.x))
AllResults = subset(AllResults, !is.na(x.y))
AllResults = subset(AllResults, select = c("PROJECT_CODE", "SITE_ID", "x.y"))
AllResults <- rename(AllResults, c(x.y = "x"))
result <- rbind(result, AllResults)
location <- subset(soil.data, select = c("Y", "X", "ID", "PROJECT_CODE", "SITE_ID"))
result <- join(result, location, by = c("PROJECT_CODE", "SITE_ID"), type = "left", match = "first")
result <- subset(result, select = c("X", "Y", "ID", "x"))
result <- rename(result, c(x = "0to15cm"))
write.table(result, "K.csv", sep = ",", col.names = TRUE, row.names = FALSE)

#Prepare data for Cubist (ASRIS K)
result <- subset(a, !is.na(ADJ)) #list of sites without nulls in K Factor
result <- aggregate(x = result$ADJ, by = list(PROJECT_CODE = result$PROJECT_CODE, SITE_ID = result$SITE_ID), FUN = "mean")
resultNA <- subset(a, is.na(ADJ)) #list of sites with nulls in K Factor
resultNA <- subset(resultNA, select = c("PROJECT_CODE", "SITE_ID", "ADJInt")) #Get K value calulated using interpolated PSA
resultNA <- rename(resultNA, c(ADJInt = "ADJ")) #Rename KInt column to K for sites without real PSA
resultNA <- aggregate(x = resultNA$ADJ, by = list(PROJECT_CODE = resultNA$PROJECT_CODE, SITE_ID = resultNA$SITE_ID), FUN = "mean")
AllResults = merge (result, resultNA, by = c("PROJECT_CODE", "SITE_ID"), all.y = TRUE)
AllResults = subset(AllResults, is.na(x.x))
AllResults = subset(AllResults, !is.na(x.y))
AllResults = subset(AllResults, select = c("PROJECT_CODE", "SITE_ID", "x.y"))
AllResults <- rename(AllResults, c(x.y = "x"))
result <- rbind(result, AllResults)
location <- subset(soil.data, select = c("Y", "X", "ID", "PROJECT_CODE", "SITE_ID"))
result <- join(result, location, by = c("PROJECT_CODE", "SITE_ID"), type = "left", match = "first")
result <- subset(result, select = c("X", "Y", "ID", "x"))
result <- rename(result, c(x = "0to15cm"))
write.table(result, "ASRIS.csv", sep = ",", col.names = TRUE, row.names = FALSE)

#End of script#