####
# Standardise PSA so they sum to 100%
# Average 0-5cm and 5-15cm standardised layers
#
# Version 1 - ?
# Version 2 - 06/04/2021 - Improved and adapted to new RSA file names
#
# User requirements
# Place all "Predicted_50th_Percentile_ModelRun_Attribute_depth.tifs into ..AttributeRasters/ModelRun directory
# Set directories
ProjectDir <- "M:/Projects/Logan_Albert_SEQW/Modelling///AttributeRasters"
ModelRun <- "PSA1"

###
# Code begins here
PSADir <- paste(ProjectDir, ModelRun, sep="//")
setwd(PSADir)

library(rgdal)
library(sp)
library(raster)

#Obtain list of depths
Depths <- list("0to5cm", "5to15cm", "15to30cm", "30to60cm", "60to100cm", "100to200cm" ) #depths modelled

### Standardise PSA layers so they don't sum to more than 100%
for (b in 1:length(Depths)){
  Filename = paste("Predicted_50th_Percentile_LASER4_Clay_x", Depths[b], ".tif", sep = "")    
  clay <- raster(Filename)
  Filename = paste("Predicted_50th_Percentile_LASER4_CS_x", Depths[b], ".tif", sep = "")    
  cs <- raster(Filename)
  Filename = paste("Predicted_50th_Percentile_LASER4_FS_x", Depths[b], ".tif", sep = "")    
  fs <- raster(Filename)
  Filename = paste("Predicted_50th_Percentile_LASER4_Silt_x", Depths[b], ".tif", sep = "")    
  silt <- raster(Filename)
  ClayRaster <- overlay(clay, cs, fs, silt, fun=function(r1, r2, r3, r4){return(100/(r1+r2+r3+r4)*r1)})
  writeRaster(ClayRaster, filename = paste("Clay_", Depths[b], "_standardised", ".tif", sep=""), format = "GTiff", overwrite = TRUE)
  CSRaster <- overlay(clay, cs, fs, silt, fun=function(r1, r2, r3, r4){return(100/(r1+r2+r3+r4)*r2)})
  writeRaster(CSRaster, filename = paste("CS_", Depths[b], "_standardised", ".tif", sep=""), format = "GTiff", overwrite = TRUE)
  FSRaster <- overlay(clay, cs, fs, silt, fun=function(r1, r2, r3, r4){return(100/(r1+r2+r3+r4)*r3)})
  writeRaster(FSRaster, filename = paste("FS_", Depths[b], "_standardised", ".tif", sep=""), format = "GTiff", overwrite = TRUE)
  SiltRaster <- overlay(clay, cs, fs, silt, fun=function(r1, r2, r3, r4){return(100/(r1+r2+r3+r4)*r4)})
  writeRaster(SiltRaster, filename = paste("Silt_", Depths[b], "_standardised", ".tif", sep=""), format = "GTiff", overwrite = TRUE)
}

# Average 0-5cm and 5-15cm standardised layers
Fractions <- c("Clay_", "CS_", "FS_", "Silt_")
for (f in 1:length(Fractions)){
  Filename = paste((Fractions[f]), "0to5cm_standardised.tif", sep = "")    
  s1 <- raster(Filename)
  Filename = paste((Fractions[f]), "5to15cm_standardised.tif", sep = "")    
  s2 <- raster(Filename)
  s3 <- overlay(s1, s2, fun=function(s1, s2){return((s1+s2)/2)}) #average the two depths
  writeRaster(s3, filename = paste((Fractions[f]), "average.tif", sep = ""), format = "GTiff", overwrite = TRUE)
}
### END OF CODE