# Load libraries
library(FIELDimageR)
library(FIELDimageR.Extra)
library(raster)
library(terra)
library(mapview)
library(sf)
library(stars)
library(dplyr)

# Create 'outputs' directory
if (!dir.exists("outputs")) {
  dir.create("outputs")
}

# Set the path to the "downsampled_orthos" folder
folder_path <- "./2024_maize_orthos/rgb/"

# Set the path to the "DSM" folder
DSM_path <- "./2024_maize_orthos/dsm/"

# Uploading files from soil base:
DSM0 <- rast("./2024_maize_orthos/dsm/3_18_2024_Field8_Maize_P4_15m_RGB_dsm_offset.tif")

# Open shapefile 
EX1.Shape<- st_read("./shapefile/2024_maize_updated.shp") 

# Get a list of all files ending in "_downsample.tif"
files <- list.files(path = folder_path, pattern = "\\.tif$")

# Iterate through the files
for (ortho_path in files) {
  
  # Remove the ".tif" substring from the ortho_path string
  result <- gsub(".tif", "", ortho_path, fixed = TRUE)
  
  # Print the result
  print(result)
  
  # Open the orthomosaic
  EX1 <- rast(file.path(folder_path, ortho_path))
  EX1 <- aggregate(EX1, fact=4) #10)
  
  # Remove soil pixels
  EX1.RemSoil <- fieldMask(mosaic = EX1, Red = 1, Green = 2, Blue = 3, index = "HUE")
  
  # Calculate canopy cover
  print("Extracting canopy cover.")
  EX1.Canopy <- fieldArea(mosaic = EX1.RemSoil$newMosaic, fieldShape = EX1.Shape)
  
  # Calculate vegetation indices
  print("Extracting vegetation indices.")
  EX1.Indices <- fieldIndex(mosaic = EX1.RemSoil$newMosaic, Red = 1, Green = 2, Blue = 3,
                            index = c("NGRDI","BGI", "GLI", "BI", "SI", "VARI"),
                            plot = FALSE)
  
  # Visualize the indices
  EX1.Info<- fieldInfo_extra(mosaic = EX1.Indices, fieldShape = EX1.Shape)
  
  # Get DSM filename
  dsm_file <- gsub("transparent_mosaic_group1.tif", "dsm_offset.tif", ortho_path, fixed = TRUE)
  
  # Load DSM file
  DSM1 <- rast(file.path(DSM_path, dsm_file))
  
  # Canopy Height Model (CHM) and Canopy Volume Model (CVM):
  CHVM<-fieldHeight(DSM0,DSM1)
  # plot(CHVM)
  
  # Removing the soil using mask from step 4:
  CHVM <- fieldMask(CHVM, mask = EX1.RemSoil$mask)
  
  print('Extracting plant height.')
  # Extracting the estimate plant height average (PlantHeight):
  plant_height <- fieldInfo_extra(mosaic = CHVM$newMosaic$height,
                              fieldShape = EX1.Shape,
                              fun = "mean")
  
  colnames(plant_height)[dim(plant_height)[2]-1]<-"PlantHeight" # Changing trait name!

  # Combine indices, canopy cover, and EPH
  print("Combining phenotypes.")
  indices_data <- as.data.frame(EX1.Info)[,-dim(EX1.Info)[2]] %>% dplyr::select(-matches(result))
  canopy_cover_data <- as.data.frame(EX1.Canopy)[,-dim(EX1.Canopy)[2]] %>% dplyr::select(PlotID, AreaPercentage)

  # Merge the dataframes using the index column
  combined_data <- merge(indices_data, canopy_cover_data, by = "PlotID")
  combined_data <- merge(combined_data, as.data.frame(plant_height) %>% dplyr::select(PlotID,"PlantHeight"), by ="PlotID")

  # Add ".csv" to the end of the result string
  result <- paste0("./outputs/", result, ".csv")

  write.csv(combined_data, file = result, row.names = FALSE)
  
  # Clear memory
  rm(result, EX1, EX1.RemSoil, EX1.Canopy, EX1.Indices, DSM1, DSM0.R, CHM, CHM.S, EPH, combined_data)
}
