install.packages(c('terra','mapview','sf','stars','caret','devtools', 
                   'leafsync', 'nlme', 'lwgeom', 'mapedit', 'exactextractr',
                   'doParallel', 'attempt', 'config', 'DT', 'git2r',
                   'DescTools', 'fields'))

# Install and load the curl package
if (!require(curl)) {
  install.packages("curl")
  library(curl)
}

# Install and load the archive package
if (!require(archive)) {
  install.packages("archive")
  library(archive)
}

install.packages("BiocManager")
BiocManager::install("EBImage")

# Download orthomosaics
curl_download("https://data.cyverse.org/dav-anon/iplant/projects/phytooracle/data_to_share/2024_maize_orthos.zip", destfile = "2024_maize_orthos.zip")
unzip("./2024_maize_orthos.zip") 
# Unzip the file
archive::archive_extract("2024_maize_orthos.zip") #, dir = "2024_maize_orthos")

# Download FIELDimageR from the provided GitHub link
download.file("https://github.com/OpenDroneMap/FIELDimageR/archive/refs/heads/master.zip", destfile = "FIELDimageR-master.zip")
# Unzip and install FIELDimageR
unzip("FIELDimageR-master.zip") 
file.rename("FIELDimageR-master", "FIELDimageR") 
shell("R CMD build FIELDimageR") # or system("R CMD build FIELDimageR")

# Get the filename of the generated tar.gz file for FIELDimageR
fieldimageR_filename <- list.files(pattern = "FIELDimageR_.*\\.tar\\.gz$")
install.packages(fieldimageR_filename, repos = NULL, type="source")

# Assuming you also want to download and install FIELDimageR.Extra
download.file("https://github.com/filipematias23/FIELDimageR.Extra/archive/refs/heads/main.zip", destfile = "FIELDimageR.Extra-main.zip")
# Unzip and install FIELDimageR.Extra
unzip("FIELDimageR.Extra-main.zip") 
file.rename("FIELDimageR.Extra-main", "FIELDimageR.Extra") 
shell("R CMD build FIELDimageR.Extra") # or system("R CMD build FIELDimageR.Extra")

# Get the filename of the generated tar.gz file for FIELDimageR.Extra
fieldimageR_Extra_filename <- list.files(pattern = "FIELDimageR\\.Extra_.*\\.tar\\.gz$")
install.packages(fieldimageR_Extra_filename, repos = NULL, type="source")

# Remove FIELDimageR and FIELDimageR.Extra directories
unlink("FIELDimageR", recursive = TRUE)
unlink("FIELDimageR.Extra", recursive = TRUE)

# Delete the downloaded zip files
file.remove(fieldimageR_filename)
file.remove(fieldimageR_Extra_filename)
file.remove('2024_maize_orthos.zip')
file.remove('FIELDimageR-master.zip')
file.remove('FIELDimageR.Extra-main.zip')