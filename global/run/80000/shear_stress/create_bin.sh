#! /bin/bash

# this is used purely for the run directory

# Ice margin file for the desired time
time=$(awk '{if (NR == 1) print $0}' ../run_parameters)
adjust_file=$(awk '{if (NR == 17) print $0}' ../run_parameters)

root_directory=$(awk '{if (NR==1) print $0}' root_directory)

margin_file=../margins/${time}.gmt

# leave blank if create_ss_grid is in ${PATH}; here we call it explicitly
bin_path="${root_directory}/.."

# The GMT formatted text file needs to be created before running this script.
# Steps:
# 1) Open shear_stress_domains_reproj.shp in QGIS
# 2) Right click on "shear_stress_domains_reproj " in the Layers dialog and click on "save as"
# 3) In format, select "Generic Mapping Tools (GMT)"; in save as, find the path to the current directory and use the file name "shear_stress_domains.gmt";
#    in Symbology export, select "feature symbology"; then hit save

domain_gmt_file=shear_stress_domains.gmt

# load projection information
source ../projection_info.sh

# grid spacing in metres (resolution is in km)
spacing=${resolution}000

# ---------------------------------------------------------------------------
# DOMAIN ALIGNMENT FIX:
# Force the shear-stress grid to use the SAME Cartesian domain as the
# elevation grid (0–7 750 000, 0–5 950 000, 5 km spacing).
# This removes the mismatch that caused "grid value out of bounds".
# ---------------------------------------------------------------------------
x_min=0
x_max=7750000
y_min=0
y_max=5950000

bin_file="shear_stress.bin"

# Colour table for plotting
gmt makecpt -Cwysiwyg -T0/200000/10000 -I > shades_shearstress.cpt

# Parameters file used by create_ss_grid and ICESHEET
cat << EOF > ss_parameters.txt
${bin_file}
${x_min}
${x_max}
${y_min}
${y_max}
${spacing}
EOF

# convert the GMT domains file into a binary grid using create_ss_grid
echo /Users/slight/Documents/icesheet/create_ss_grid

if [ "${adjust_file}" = "" ]
then
    /Users/slight/Documents/icesheet/create_ss_grid ${domain_gmt_file} domains_max.txt
else
    if [ -f "domains_min.txt" ]
    then
        /Users/slight/Documents/icesheet/create_ss_grid ${domain_gmt_file} domains_max.txt ${adjust_file} ${time} domains_min.txt
    else
        /Users/slight/Documents/icesheet/create_ss_grid ${domain_gmt_file} domains_max.txt ${adjust_file} ${time}
    fi
fi

nc_file=shear_stress.nc

# Build the shear-stress NetCDF grid on the aligned domain
gmt xyz2grd shear_stress_grid.txt -I${spacing} -R${x_min}/${x_max}/${y_min}/${y_max} -G${nc_file}

# plot the file
plot="shear_stress.ps"

gmt grdimage ${nc_file} -Y12 -R${x_min}/${x_max}/${y_min}/${y_max} -JX${map_width}/0 -K -P -Cshades_shearstress.cpt -V -nb > ${plot}

# Now compute a plotting region in projected coords for the map frame
gmt mapproject << END ${R_options} ${J_options} -F -C > corners.txt
${west_longitude} ${west_latitude}
${east_longitude} ${east_latitude}
END

r1=$(awk 'NR==1{print $1}' corners.txt)
r2=$(awk 'NR==2{print $1}' corners.txt)
r3=$(awk 'NR==1{print $2}' corners.txt)
r4=$(awk 'NR==2{print $2}' corners.txt)

gmt psxy ${domain_gmt_file} -R${r1}/${r2}/${r3}/${r4} -JX -K -O -P -V -Wthin >> ${plot}

gmt pscoast -Bafg -O -K ${R_options} ${J_options} -P -Wthin -Di -A5000 -Wthinnest,grey >> ${plot}

gmt psxy ${margin_file} ${R_options} ${J_options} -K -O -P -V -Wthickest,white >> ${plot}
gmt psxy ${margin_file} ${R_options} ${J_options} -K -O -P -V -Wthin,blue >> ${plot}

gmt psscale -X-1 -Y-3.5 -Dx9c/2c/9c/0.5ch -P -O -Bx100000f20000+l"Shear Stress (Pa)" --FONT_LABEL=14p -Cshades_shearstress.cpt -V >> ${plot}

# convert the grid to a GMT binary format used by ICESHEET
gmt grdconvert ${nc_file} ${bin_file}=bf
