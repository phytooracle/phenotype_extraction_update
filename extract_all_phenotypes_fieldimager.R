# Load necessary libraries
library(FIELDimageR)
library(FIELDimageR.Extra)
library(terra)
library(mapview)
library(sf)
library(stars)
library(dplyr)
library(logging)

# Initialize logging
basicConfig()
addHandler(writeToFile, file = "processing.log", level = 'DEBUG')

# Create 'outputs' directory if it doesn't exist
create_output_directory <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    loginfo("Created output directory: %s", path)
  }
}

# Load base DSM
load_base_dsm <- function(dsm_path) {
  if (file.exists(dsm_path)) {
    DSM0 <- rast(dsm_path)
    loginfo("Loaded base DSM from %s", dsm_path)
    return(DSM0)
  } else {
    logerror("Base DSM file not found at %s", dsm_path)
    stop("Base DSM file not found.")
  }
}

# Load shapefile
load_shapefile <- function(shapefile_path) {
  if (file.exists(shapefile_path)) {
    EX1.Shape <- st_read(shapefile_path)
    loginfo("Loaded shapefile from %s", shapefile_path)
    return(EX1.Shape)
  } else {
    logerror("Shapefile not found at %s", shapefile_path)
    stop("Shapefile not found.")
  }
}

# Get list of orthomosaic files
get_orthomosaic_files <- function(folder_path) {
  files <- list.files(
    path = folder_path,
    pattern = "\\.tif$",
    full.names = TRUE,
    recursive = TRUE
  )
  # Filter files
  files <- files[
    grepl("mosaic", files) &
      !grepl("MS/", files) &
      !grepl("dsm\\.tif$", files) &
      !grepl("tiles", files)
  ]
  loginfo("Found %d orthomosaic files.", length(files))
  return(files)
}

# Process each orthomosaic file
process_orthomosaic <- function(
    ortho_path,
    DSM0,
    EX1.Shape,
    outpath,
    n_split,
    ExtractPH,
    user_DSM_path = NULL  # Added optional DSM_path parameter
) {
  # Get the base filename without extension
  result <- tools::file_path_sans_ext(basename(ortho_path))
  
  # Construct the output CSV filename
  result_full <- file.path(outpath, paste0(result, ".csv"))
  
  # Check if the CSV file already exists
  if (file.exists(result_full)) {
    loginfo("Output file %s already exists. Skipping.", result_full)
    return(NULL)
  }
  
  loginfo("Processing orthomosaic: %s", ortho_path)
  
  # Try-catch block for error handling
  tryCatch({
    # Open the orthomosaic
    EX1 <- rast(ortho_path)
    
    # Aggregate the raster to reduce resolution (factor of 4)
    EX1 <- aggregate(EX1, fact = 4)
    
    # Remove soil pixels using HUE index
    EX1.RemSoil <- fieldMask(
      mosaic = EX1,
      Red = 1, Green = 2, Blue = 3,
      index = "HUE",
      plot = FALSE
    )
    
    # Calculate canopy cover
    loginfo("Extracting canopy cover.")
    EX1.Canopy <- fieldArea(
      mosaic = EX1.RemSoil$newMosaic,
      fieldShape = EX1.Shape
    )
    
    # Initialize DSM_path and dsm_file
    DSM_path <- NULL
    dsm_file <- NULL
    
    # Determine the type of orthomosaic and process accordingly
    if (grepl("multiband", ortho_path, fixed = TRUE)) {
      # Multiband images
      loginfo("Extracting vegetation indices for multiband image.")
      EX1.Indices <- fieldIndex(
        mosaic = EX1.RemSoil$newMosaic,
        Red = 1, Green = 2, Blue = 3, NIR = 4, RedEdge = 5,
        index = c("NGRDI", "BGI", "GLI", "BI", "SI", "VARI", "NDVI", "NDRE"),
        plot = FALSE
      )
      if (ExtractPH) {
        # Get DSM filename
        dsm_file <- gsub(
          "transparent_mosaic_multiband_output.tif",
          "dsm_adjusted.tif",
          basename(ortho_path),
          fixed = TRUE
        )
        if (!is.null(user_DSM_path)) {
          DSM_path <- user_DSM_path
        } else {
          # Construct DSM_path based on ortho_path
          DSM_path <- file.path(dirname(ortho_path), "3_dsm_ortho", "1_dsm")
        }
        dsm_file <- file.path(DSM_path, dsm_file)
      }
    } else if (grepl("RGB", ortho_path, fixed = TRUE)) {
      # RGB images
      loginfo("Extracting vegetation indices for RGB image.")
      EX1.Indices <- fieldIndex(
        mosaic = EX1.RemSoil$newMosaic,
        Red = 1, Green = 2, Blue = 3,
        index = c("NGRDI", "BGI", "GLI", "BI", "SI", "VARI"),
        plot = FALSE
      )
      if (ExtractPH) {
        # Get DSM filename
        dsm_file <- gsub(
          "transparent_mosaic_group1.tif",
          "dsm_adjusted.tif",
          basename(ortho_path),
          fixed = TRUE
        )
        if (!is.null(user_DSM_path)) {
          DSM_path <- user_DSM_path
        } else {
          # Construct DSM_path based on ortho_path
          DSM_path <- file.path(dirname(ortho_path), "3_dsm_ortho", "1_dsm")
        }
        dsm_file <- file.path(DSM_path, dsm_file)
      }
    } else {
      logwarn("Ortho path format incorrect: %s", ortho_path)
      return(NULL)
    }
    
    # Extract field information from indices
    EX1.Info <- fieldInfo_extra(
      mosaic = EX1.Indices,
      fieldShape = EX1.Shape,
      progress = TRUE
    )
    
    # Initialize DSM.INFO
    DSM.INFO <- NULL
    
    if (ExtractPH && !is.null(dsm_file) && file.exists(dsm_file)) {
      # Load DSM file
      DSM1 <- rast(dsm_file)
      
      # Compute Canopy Height Model (CHM) and Canopy Volume Model (CVM)
      CHVM <- fieldHeight(DSM0, DSM1)
      
      # Remove soil pixels from CHVM
      CHVM <- fieldMask(CHVM, mask = EX1.RemSoil$mask)
      
      loginfo('Extracting plant height.')
      
      # Extract mean plant height
      DSM.INFO <- fieldInfo_extra(
        mosaic = CHVM$newMosaic$height,
        fieldShape = EX1.Shape,
        fun = 'mean'
      ) %>% dplyr::rename(PlantHeight = height_mean)
      
      # Extract 10th and 90th percentile of plant height
      probs <- c(0.1, 0.9)
      EPH.Extract <- terra::extract(
        CHVM$newMosaic$height, EX1.Shape,
        fun = function(x) quantile(x, probs = probs, na.rm = TRUE)
      )
      
      DSM.INFO<- merge(DSM.INFO,EPH.Extract,by="ID") %>% 
        dplyr::rename(PH.10 = height, PH.90 = height.1)
      
      # Extract plant volume (digital biomass)
      EPB.Extract <- fieldInfo_extra(
        mosaic = CHVM$newMosaic$volume,
        fieldShape = EX1.Shape,
        fun = 'sum'
      ) %>%
        select('ID',"volume_sum") %>%
        st_drop_geometry()
      
      DSM.INFO <- merge(DSM.INFO,EPB.Extract,by="ID") %>% 
        dplyr::rename(PlantBiomass = volume_sum)
      
    } else if (ExtractPH) {
      logwarn("DSM file not found or missing: %s", dsm_file)
    }
    
    # Combine indices, canopy cover, and plant height data
    loginfo("Combining phenotypes.")
    indices_data <- as.data.frame(EX1.Info) %>%
      st_drop_geometry()
    canopy_cover_data <- as.data.frame(EX1.Canopy) %>% dplyr::select(PlotID, AreaPercentage) %>% 
      st_drop_geometry()
    
    # Merge the dataframes using 'PlotID' column
    combined_data <- merge(indices_data, canopy_cover_data, by = "PlotID")
    if (ExtractPH && !is.null(DSM.INFO)) {
      combined_data <- merge(
        combined_data,
        DSM.INFO %>%
          dplyr::select(PlotID, PlantHeight, PH.10, PH.90, PlantBiomass) %>% 
          st_drop_geometry(),
        by = "PlotID"
      )
    }
    
    # Adjust columns to correct values based on the number of splits
    betweencols <- (max(combined_data$column) - 2 * n_split) / (n_split + 1)
    combined_data <- combined_data %>% filter(plot < 9000)
    combined_data$Column <- combined_data$column - trunc((combined_data$column) / (betweencols + 2)) * 2
    
    # Write combined data to CSV
    write.csv(combined_data, file = result_full, row.names = FALSE)
    loginfo("Successfully wrote output to %s", result_full)
    
  }, error = function(e) {
    print(e)
    logerror(sprintf("Error processing %s: %s", ortho_path, e$message))
  })
}

# Main processing function
process_all_orthomosaics <- function(
    folder_path,
    base_dsm_path,
    shapefile_path,
    outpath,
    n_split,
    ExtractPH = TRUE,
    DSM_path = NULL  # Added optional DSM_path parameter
) {
  # Create output directory
  create_output_directory(outpath)
  
  # Load base DSM and shapefile
  DSM0 <- load_base_dsm(base_dsm_path)
  EX1.Shape <- load_shapefile(shapefile_path)
  
  # Get list of orthomosaic files
  files <- get_orthomosaic_files(folder_path)
  
  # Process each file
  for (ortho_path in files) {
    process_orthomosaic(
      ortho_path = ortho_path,
      DSM0 = DSM0,
      EX1.Shape = EX1.Shape,
      outpath = outpath,
      n_split = n_split,
      ExtractPH = ExtractPH,
      user_DSM_path = DSM_path
    )
  }
}

# Set parameters
folder_path <- "./2024_maize_orthos/rgb/"
base_dsm_path <- "./2024_maize_orthos/dsm/3_18_2024_Field8_Maize_P4_15m_RGB_dsm_offset.tif"
shapefile_path <- "./shapefile/2024_maize_updated.shp"
outpath <- "./outputs/Maize"
n_split <- 1
ExtractPH <- TRUE

# Optionally set DSM_path
# Note: If you do not set the DSM Path this will assume the DSM is located the the folder "folder_path/*/3_dsm_ortho/1_dsm"
# Using the assumed pathing may lead to errors, for easy use set the DSM_Path
# Also Note that this code assumes the dsm file names are "ortho_filename_dsm_adjusted.tif" 
# if this is not the case you can change it on lines 131 and 156 for Multispec and RGB Respectively 
DSM_path <- './2024_maize_orthos/dsm/'

# Run the processing
process_all_orthomosaics(
  folder_path = folder_path,
  base_dsm_path = base_dsm_path,
  shapefile_path = shapefile_path,
  outpath = outpath,
  n_split = n_split,
  ExtractPH = ExtractPH,
  DSM_path = DSM_path  # Comment this out if DSM_path is not available 
)


# To process a single Ortho Uncomment and run the below code
# ortho_path <- "./2024_maize_orthos/rgb/3_18_2024_Field8_Maize_P4_15m_RGB_transparent_mosaic_group1.tif"
# DS0 <- load_base_dsm("./2024_maize_orthos/dsm/3_18_2024_Field8_Maize_P4_15m_RGB_dsm_offset.tif")
# EX1.Shape <- load_shapefile("./shapefile/2024_maize_updated.shp")
# outpath <- "./outputs/Maize"
# n_split <- 1
# ExtractPH <- TRUE
# DSM_path <- "./2024_maize_orthos/dsm/3_18_2024_Field8_Maize_P4_15m_RGB_dsm_offset.tif"
#   
# # Run the processing
# process_orthomosaic(
#   ortho_path = ortho_path,
#   DSM0 = DSM0,
#   EX1.Shape = EX1.Shape,
#   outpath = outpath,
#   n_split = n_split,
#   ExtractPH = ExtractPH,
#   user_DSM_path = DSM_path
# )