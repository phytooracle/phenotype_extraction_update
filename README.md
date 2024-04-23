# Phenotype Extraction

This R notebook is written to extract phenotype information from drone imagery using [FieldImageR](https://github.com/OpenDroneMap/FIELDimageR). This repo contains the following:

- Shapefile: `shapefile\` containing the spatial polygons representing field plots. 
- Fieldmap: `fieldmaps\` containing the spatial organization of field plots.
- R notebooks: `install_fieldimager.R, create_fieldmap.Rmd, create_shapefile.Rmd, extract_all_phenotypes_fieldimager.R`

We will use these files to test FieldImageR

# Table of Contents

- [Download the GitHub repo](#download-the-github-repo)
- [Install FieldImageR](#install-fieldimager)
- [Create fieldmap and shapefile](#create-fieldmap-and-shapefile)
- [Run phenotype extraction script](#run-phenotype-extraction-script)

## Download the GitHub repo

Download the repo by clicking Code > Download ZIP:

![Alt text](img/download_zip.png?raw=true "Title")

Now, extract the contents of the ZIP file:

![Alt text](img/extract_zip.png?raw=true "Title")

Copy the path of the folder:

![Alt text](img/contents_filepath.png?raw=true "Title")

In RStudio, set the working directory to this copied path:

![Alt text](img/set_wd.png?raw=true "Title")

![Alt text](img/home_dir.png?raw=true "Title")

## Install FieldImageR
To install FieldImageR, FieldImageR.Extra, and dependencies, run the ```install_fieldimager.R``` script.

> **Note:** This script will also download red-green-blue (RGB) and digital surface model (DSM) orthomosaics from our 2024 maize trial.

## Create fieldmap and shapefile
Before extraction, we must create a fieldmap and shapefile.

To create a fieldmap, run the ```create_fieldmap.Rmd``` notebook.

To create a shapefile, run the ```create_shapefile.Rmd``` notebook.

> **Note:** Generating the fieldmap and shapefile is the responsibility of the graduate student or postdoc in charge of the project. These files are generated once per season and shared with the lab member who will be running processing.

## Run phenotype extraction script
To run phenotype extraction, including vegetation indices, canopy cover, and plant height, run the ```extract_all_phenotypes_fieldimager.R``` file.

As orthomosaics become available throughout the seasons, you can add them to ```2024_maize_orthos```. Make sure to place RGB orthomosaics in ```2024_maize_orthos/rgb``` and DSM orthomosaics in ```2024_maize_orthos/dsm```. Once both RGB and DSM are added for a new flight, you can extract phenotypes from them using the ```extract_all_phenotypes_fieldimager.R``` file.
