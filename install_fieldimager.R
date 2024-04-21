install.packages(c('terra','mapview','sf','stars','caret','devtools', 
                   'leafsync', 'nlme', 'lwgeom', 'mapedit', 'exactextractr'))

# Download FIELDimageR from the provided GitHub link
download.file("https://github.com/OpenDroneMap/FIELDimageR/archive/refs/heads/master.zip", destfile = "FIELDimageR-master.zip")

# Set the working directory to the location where the zip file is saved
setwd("~/") # Adjust this to your actual working directory

# Unzip and install FIELDimageR
unzip("FIELDimageR-master.zip") 
file.rename("FIELDimageR-master", "FIELDimageR") 
shell("R CMD build FIELDimageR") # or system("R CMD build FIELDimageR")

# Get the filename of the generated tar.gz file for FIELDimageR
fieldimageR_filename <- list.files(pattern = "FIELDimageR_.*\\.tar\\.gz$")
install.packages(fieldimageR_filename, repos = NULL, type="source")

# Assuming you also want to download and install FIELDimageR.Extra
download.file("https://github.com/filipematias23/FIELDimageR.Extra/archive/refs/heads/main.zip", destfile = "FIELDimageR.Extra-main.zip")
setwd("~/") # Adjust this to your actual working directory

# Unzip and install FIELDimageR.Extra
unzip("FIELDimageR.Extra-main.zip") 
file.rename("FIELDimageR.Extra-main", "FIELDimageR.Extra") 
shell("R CMD build FIELDimageR.Extra") # or system("R CMD build FIELDimageR.Extra")

# Get the filename of the generated tar.gz file for FIELDimageR.Extra
fieldimageR_Extra_filename <- list.files(pattern = "FIELDimageR\\.Extra_.*\\.tar\\.gz$")
install.packages(fieldimageR_Extra_filename, repos = NULL, type="source")

# Delete the downloaded zip files
file.remove("FIELDimageR-master.zip")
file.remove("FIELDimageR.Extra-main.zip")
