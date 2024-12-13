# FLIM_nano

## Supplementary Code 1 and Code 2 are for Phasor plot analysis of mitochondrial polarization in organoids

PTU files and exported CSV files for phasor plot analysis of mitochondrial polarization in organoids are available on Zenodo (https://zenodo.org/records/14417182).

## Instructions for Supplementary Code 1

Follow the steps below to set up the environment and run the **Supplementary Code 1**.

## 1. Install Miniforge

Download and install Miniforge from the [Miniforge GitHub repository](https://github.com/conda-forge/miniforge).

## Create a new environment named 'napari-flim-phasor-env' with Python 3.9 from the [Miniforge GitHub repository](https://github.com/zoccoler/napari-flim-phasor-plotter)
mamba create -n napari-flim-phasor-env python=3.9 napari pyqt git

## Activate the environment
mamba activate napari-flim-phasor-env

## Install All Optional Dependencies
pip install napari-flim-phasor-plotter shapely

## Start Napari
napari

In Napari, open the console from the menu: View -> Console.
Paste the Supplementary Code 1 into the console and press Enter to run it



https://github.com/user-attachments/assets/98079d30-7609-48b9-b131-6d120adb5a8a



## Instructions for Supplementary Code 2

download the data from Zenodo (https://zenodo.org/records/14417182), run this code to get plots in jupter notebook or google colab after change the file path to your folder.

## Supplementary Code 3, Code 4 and Code 5 are for mitochondrial dynamics and morphology analysis

## Instructions for Supplementary Code 3

This code was used to split channels from ome-tiff images exported from Leica LAS X

## Open Leica LAS X, select the data file and right click to export OME-TIFF images of all channels 

## Ensure you have set up the napari-nellie environment from [Nellie GitHub repository](https://github.com/aelefebv/nellie)

## Install the required package:
pip install tifffile  lxml

In Napari, open the console from the menu: View -> Console.
Paste the Supplementary Code 3 into the console and press Enter to run it.  

## Instructions for Supplementary Code 4
Multiple-files running with Nellie.

## Instructions for Supplementary Code 5
download the data from Zenodo (https://zenodo.org/records/14417688), run this code to get plots in jupter notebook or google colab after change the file path to your folder.

