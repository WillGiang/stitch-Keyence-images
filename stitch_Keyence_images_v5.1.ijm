// stitch_Keyence_images.ijm
// v5.1
// 
// Release Notes
// --------------------------------------------
// v5.1   2018-12-13 Added RGB functionality. 
//    Assumes the following relationship between channels and colors
//    CH 1 : Green 
//    CH 2 : Red
//    CH 3 : Blue
//
// Author: William Giang | wgiang@emory.edu
// Last updated: 2018-12-13
// https://github.com/WillGiang/stitch-Keyence-images


// *** User Input *** //
dir_in = getDirectory("Choose data directory with individual channel images from Keyence");

Dialog.create("Alan Sokoloff's stitching macro for Keyence");
Dialog.addCheckbox("Remove thumbnails only (no stitching)", false);
Dialog.addNumber("Grid x:", 3);
Dialog.addNumber("Grid y:", 1);
Dialog.addCheckbox("CH1", true);
Dialog.addCheckbox("CH2", false);
Dialog.addCheckbox("CH3", false);
Dialog.addCheckbox("CH4", false);
Dialog.addCheckbox("want hyperstack (saves a hyperstack.tif in data dir", false);
Dialog.addCheckbox("compute overlap (leave unchecked to assume 30%)", false);
Dialog.show();

// *** Parse Dialog *** //
want_to_remove_thumbnail_only = Dialog.getCheckbox();
grid_x = Dialog.getNumber();
grid_y = Dialog.getNumber();
want_CH1 = Dialog.getCheckbox();
want_CH2 = Dialog.getCheckbox();
want_CH3 = Dialog.getCheckbox();
want_CH4 = Dialog.getCheckbox();
want_hyperstack = Dialog.getCheckbox();
want_compute_overlap = Dialog.getCheckbox();

setBatchMode(true);

// *** Determine correct file name list *** //
// 	- Selects images of individual channels (ignores overlay images)
//  - Does not contain any directory information, will be added later
function select_file_list(all_files_array){
	selected_file_list = newArray();
	for (i=0; i < all_files_array.length; i++){
		if (matches(all_files_array[i], ".*CH.*")){
			selected_file_list = Array.concat(selected_file_list, all_files_array[i]);
		}
	}
	return selected_file_list;
}

all_files = getFileList(dir_in);
filename_list = select_file_list(all_files);

// *** Populate CH_array and make desired directories *** //
CH_array = newArray(); // will be something like [CH1/, CH2/, CH3/, CH4/]
want_CH_array = newArray(want_CH1, want_CH2, want_CH3, want_CH4);
actual_CH_dir_array = newArray(); // contains absolute paths for channel dirs

for (i=0; i < want_CH_array.length; i++){
	if (want_CH_array[i]){
		actual_CH = "CH" + i + 1; // + 1 because channels start at 1, not 0
		actual_CH_dir_array = Array.concat(actual_CH_dir_array, dir_in + actual_CH);
		CH_array = Array.concat(CH_array, actual_CH + File.separator);
		File.makeDirectory(dir_in + actual_CH + File.separator);
	}
}
n_channels = actual_CH_dir_array.length;
// *** Remove "helpful" Keyence thumbnails from tiffs by splitting/saving by channel *** //
// Fiji thinks Keyence's 
// 	- CH1 is actually C2
//  - CH2 is actually C1
//  - CH3 is C3
//  - CH4 is C1 and C3 (duplicated, so either works?)

function removeThumbnailAndSave(file_list){
	for (i=0; i < file_list.length; i++) {
		file_path_name = dir_in + file_list[i];
		if (!File.isDirectory(file_path_name) && endsWith(file_path_name, ".tif")){
			open(file_path_name);
			
			nSlicesInFile = nSlices;  // get number of channels in image BEFORE splitting
			
			// nSlices returns 1 for RGB images. 
			if ( bitDepth() == 24){nSlicesInFile = 3;} 
			
			run("Split Channels");

			for (j=0; j < nSlicesInFile; j++){
				title = getTitle();
				print(title);
				// Fiji/ImageJ prepends `C#` to individual channels
				if (startsWith(title, "C1") && want_CH4 && endsWith(title, "CH4.tif")){
					//run("Magenta");
					saveAs("Tiff", dir_in + "CH4" + File.separator + title);
				}
				else if (startsWith(title, "C3") && want_CH3 && endsWith(title, "CH3.tif")){
					//run("Blue");
					saveAs("Tiff", dir_in + "CH3" + File.separator + title);
				}
				else if (startsWith(title, "C1") && want_CH2 && endsWith(title, "CH2.tif")){
					//run("Red");
					saveAs("Tiff", dir_in + "CH2" + File.separator + title);
				}
				else if (startsWith(title, "C2") && want_CH1 && endsWith(title, "CH1.tif")){
					//run("Green");
					saveAs("Tiff", dir_in + "CH1" + File.separator + title);
				}

				// If these are RGB images, then splitting channels will
				// affix the color at the end.
				//  e.g. foo.tif -> foo.tif (green), foo.tif (blue), foo.tif (red)

				else if (want_CH1 && endsWith(title, "(green)")){
					ind = indexOf(title, " (green)");
					
					no_green_title = substring(title, 0, ind);
					//saveAs("Tiff", dir_in + "CH1" + File.separator + "C1-"+ title);
					if (endsWith(no_green_title, "CH1.tif")){
					saveAs("Tiff", dir_in + "CH1" + File.separator + no_green_title);
					}				
				}
				else if (want_CH2 && endsWith(title, "(red)")){
					ind = indexOf(title, " (red)");
					
					no_red_title = substring(title, 0, ind);
					//saveAs("Tiff", dir_in + "CH1" + File.separator + "C1-"+ title);
					if (endsWith(no_red_title, "CH2.tif")){
					saveAs("Tiff", dir_in + "CH2" + File.separator + no_red_title);
					}
				}
				else if (want_CH3 && endsWith(title, "(blue)")){
					ind = indexOf(title, " (blue)");
					
					no_blue_title = substring(title, 0, ind);
					//saveAs("Tiff", dir_in + "CH1" + File.separator + "C1-"+ title);
					if (endsWith(no_blue_title, "CH3.tif")){
					saveAs("Tiff", dir_in + "CH3" + File.separator + no_blue_title);
					}
				}
				close();
			}
		}
	}
}

removeThumbnailAndSave(filename_list);

if (want_to_remove_thumbnail_only){
	setBatchMode(false);
	exit("You opted for removing thumbnails only instead of stitching.");
	}
	
// *** Parse filename  ***//
// The suffix for CH images goes like #####_Z###_CH#.tif
// where
// 	- the first set of # refers to the tiling iteration number
//  - Z### refers to the Z level
//  - CH# refers to the channel number
// 
// We can use the characters _ and . to help index our string

function getSuffix(file_name){
	first_suffix_index = lastIndexOf(file_name, "_0");
	if (first_suffix_index == -1){first_suffix_index = lastIndexOf(file_name, "{");}
	last_suffix_index = lastIndexOf(file_name, ".");
	suffix = substring(file_name, first_suffix_index, last_suffix_index);
	// suffix should be something like `_00001_Z001_CH1`
	return suffix;
}

// determine z-levels
// look at one of the created CH directories for filenames
function parseFileNamesForMaxZ(actual_CH_dir_array){
	max_z = 1;
	ch_file_list = getFileList(actual_CH_dir_array[0]);
	
	for (i=0; i < ch_file_list.length; i++){
		file_name = ch_file_list[i];
		
		suffix = getSuffix(file_name);
		z_level = parseInt(substring(suffix, indexOf(suffix, "Z")+1, lastIndexOf(suffix, "_")));
		
		if (z_level > max_z){max_z = z_level;}
	}
	
	return max_z;
}

max_z = parseFileNamesForMaxZ(actual_CH_dir_array);

// *** Determine a properly formatted filename sample for Grid/Collection stitching ***

function prepareIterationFileName(dir){
	files = getFileList(dir);
	file = files[0];
	suffix = getSuffix(file);
	tiling_iteration_substring = "{iiiii}";
	new_suffix = replace(suffix, substring(suffix, 1, 6), tiling_iteration_substring);
	iteration_file_name = replace(file, suffix, new_suffix);

	return iteration_file_name;
}


function fixZFileName(filename, z_level){
	suffix = getSuffix(filename);
	suffix_idx = indexOf(filename, suffix);
	prefix = substring(filename, 0, suffix_idx);
	
	Z_index_start = lastIndexOf(suffix, "Z");
	suffix1 = substring(suffix, 0, Z_index_start);
	suffix2 = "Z" + z_level;
	suffix3 = substring(suffix, Z_index_start + 4);

	stitched_suffix = suffix1 + suffix2 + suffix3;
	stitched_file_name = prefix + stitched_suffix + ".tif";
	//stitched_file_name = replace(filename, suffix, stitched_suffix);
	
	return stitched_file_name;
}

// *** Bring everything together and submit for stitching *** //
// ** removed `compute overlap` from Grid/Collection stitching options.
// ** Different channels would yield different end result dimensions, especially if one was mostly empty.

function stitchZStackForAChannel(max_z, grid_x, grid_y, file_format, channel, dir_in, want_compute_overlap){
	for (j = 1; j <= max_z; j++){
		z_level = IJ.pad(j,3);
		output_textfilename = "TileConfiguration" + z_level + ".txt";
		dir_out = dir_in + "stitched" + File.separator;
		File.makeDirectory(dir_out);

		channel_dir = dir_in + channel;
		CH_str = substring(channel, 0, lengthOf(channel)-1);  // remove the File.separator at end
		stitching_file_format = fixZFileName(file_format, z_level);
		//run("Grid/Collection stitching", "type=[Grid: snake by rows] order=[Right & Down                ] grid_size_x=&grid_x grid_size_y=&grid_y tile_overlap=&tile_overlap first_file_index_i=1 directory=&channel_dir file_names=&file_format output_textfile_name=&output_textfilename fusion_method=[Linear Blending] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 compute_overlap computation_parameters=[Save computation time (but use more RAM)] image_output=[Write to disk] output_directory=&dir_out");
		if (want_compute_overlap){run("Grid/Collection stitching", "type=[Grid: snake by rows] order=[Right & Down                ] grid_size_x=&grid_x grid_size_y=&grid_y tile_overlap=30 first_file_index_i=1 directory=&channel_dir file_names=&stitching_file_format output_textfile_name=&output_textfilename fusion_method=[Linear Blending] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 compute_overlap computation_parameters=[Save computation time (but use more RAM)] image_output=[Write to disk] output_directory=&dir_out");}
		else {run("Grid/Collection stitching", "type=[Grid: snake by rows] order=[Right & Down                ] grid_size_x=&grid_x grid_size_y=&grid_y tile_overlap=30 first_file_index_i=1 directory=&channel_dir file_names=&stitching_file_format output_textfile_name=&output_textfilename fusion_method=[Linear Blending] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 computation_parameters=[Save computation time (but use more RAM)] image_output=[Write to disk] output_directory=&dir_out");}
		File.rename(dir_out + "img_t1_z1_c1", dir_out + "stitched_Z" + z_level + "_" + CH_str + ".tif");
		File.delete(channel_dir + output_textfilename);  // deletes TileConfiguration###.txt
		File.delete(channel_dir + "TileConfiguration" + z_level + ".registered.txt");
	}
}

function fixZFileName(filename, z_level){
	suffix = getSuffix(filename);
	suffix_idx = indexOf(filename, suffix);
	prefix = substring(filename, 0, suffix_idx);
	
	Z_index_start = lastIndexOf(suffix, "Z");
	suffix1 = substring(suffix, 0, Z_index_start);
	suffix2 = "Z" + z_level;
	suffix3 = substring(suffix, Z_index_start + 4);

	stitched_suffix = suffix1 + suffix2 + suffix3;
	stitched_file_name = prefix + stitched_suffix + ".tif";
	//stitched_file_name = replace(filename, suffix, stitched_suffix);
	// Using the replace() function does not work because
	// Java's regex does not like curly braces
	//
	// concatenating is easier to read/write/understand 
	return stitched_file_name;
}
// *** Loop through desired channels *** //
for (i=0; i < actual_CH_dir_array.length; i++){
	file_format = prepareIterationFileName(actual_CH_dir_array[i]);
	stitchZStackForAChannel(max_z, grid_x, grid_y, file_format, CH_array[i], dir_in, want_compute_overlap);
}



if (want_hyperstack){
	stitched_dir = dir_in + "stitched" + File.separator;
	stitched_files = getFileList(stitched_dir);
	
	for (i=0; i < stitched_files.length; i++){
		open( stitched_dir + stitched_files[i]);
	}
	run("Images to Stack", "method=[Copy (center)] name=Stack title=[] bicubic use");
	run("Stack to Hyperstack...", "order=xyczt(default) channels=&n_channels slices=&max_z frames=1 display=Composite");
	for (i=0; i< n_channels; i++){
		Stack.setChannel(i+1);
		CH = CH_array[i];
		print(CH);
		
		if (startsWith(CH, "CH1"))
			run("Green");
		else if (startsWith(CH, "CH2"))
			run("Red");
		else if (startsWith(CH, "CH3"))
			run("Blue");
		else if (startsWith(CH, "CH4"))
			run("Magenta");
	}
	saveAs("Tiff", dir_in + "hyperstack");
	close();
}

setBatchMode(false);
