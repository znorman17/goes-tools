;+
;
;  Sample routines that are used for searching for and generating
;  anomations of GOES-16 data on maps. The data should be downloaded from
;  Earth on AWS and have the expected file naming conventions. See the 
;  main level program at the bottom of the file for and example of how 
;  you can run this code.
;
; :Author: Zachary Norman - Github: znorman17
;-



;+
; :Description:
;    Simple function that searches for GOES data based on the JavaScript code
;    that downloads data from S3. 
;
; :Returns:
;    A list of files that matched the channels passed in. Each
;    element of the list will have either one or three elements
;    representing the single channel or RGB combination of files
;    that represents a scene
;
; :Params:
;    baseDir: in, required, type=string
;      Specify the directory to search for NCDF files.
;    channels: in, required, type=string/stringarr
;      Specify the channels (either one or three) that you want to
;      search for. It bundles the matches together for easier processing.
;
;      The values for this should be of the form 'C01', 'C02', ... 'C16'.
;
; :Author: Zachary Norman - GitHub: znorman17
;-
function searchGOESData, dirSearch, channels
  compile_opt idl2

  ;get the number of channels
  nChannels = n_elements(channels)

  ;check for day-directories that we might process
  cd, dirSearch, CURRENT = first_dir
  days = file_search(COUNT = count)
  cd, first_dir

  ;make sure we have dates
  if (count eq 0) then begin
    message, 'No subdirectories found that might contain data'
  endif else begin
    days = dirSearch + (dirSearch.endsWith(path_sep()) ? '' : path_sep()) + days.sort()
  endelse

  ;preallocate list to hold files
  fileList = list()

  ;loop over each day
  foreach day, days, z do begin
    ;search for what hours we need to check for data
    cd, day, CURRENT = first_dir
    hours = file_search(COUNT = count)
    cd, first_dir
    
    ;skip if nothing found
    if (count eq 0) then continue

    ;make fully-qualified
    hours = day + path_sep() + hours.sort()

    ;loop over each hour
    foreach hour, hours do begin
      ;check for times to process
      cd, hour, CURRENT = first_dir
      times = file_search(COUNT = count)
      cd, first_dir
      
      ;skip if nothing
      if (count eq 0) then continue

      ;make fully-qualified
      times = hour + path_sep() + times.sort()

      ;check each time for results
      foreach time, times do begin
        ;check what we are processing
        if (nChannels eq 1) then begin
          ;search for files and skip if we dont find any for each search (could save time)
          files1 = file_search(time, '*' + channels[0] + '*.nc', COUNT = nFiles1)
          if (nFiles1 eq 0) then continue

          ;add all files to our file list
          for i=0, nFiles1-1 do fileList.Add, [files1]
        endif else begin
          ;search for files and skip if we dont find any for each search (could save time)
          files1 = file_search(time, '*' + channels[0] + '*.nc', COUNT = nFiles1)
          if (nFiles1 eq 0) then continue
          files2 = file_search(time, '*' + channels[1] + '*.nc', COUNT = nFiles2)
          if (nFiles2 eq 0) then continue
          files3 = file_search(time, '*' + channels[2] + '*.nc', COUNT = nFiles3)
          if (nFiles2 eq 0) then continue

          ;make sure we found the same number of files for each folder
          if (n_elements(([nFiles1, nfiles2, nFiles3]).uniq()) ne 1) then begin
            continue
          endif

          ;add all files to our file list
          for i=0, nFiles1-1 do fileList.Add, [files1[i], files2[i], files3[i]]
        endelse
      endforeach
    endforeach
  endforeach

  ;return our file list
  return, fileList
end


;+
; :Description:
;    Procedure that reads in and displays GOES CONUS imagery from the 
;    Level1b Radiance product type. The routine doesn't check for product 
;    type and the map that gets displayed has a hard-coded limit set for
;    the CONUS imagery.
;
; :Params:
;    channels: in, require, type=string/stringarr
;      Specify a single channel, or three channels, that you want to
;      visualize. A single channel will have a color table applied to it
;      and three channels will be used as RGB combinations. Take care that
;      RGB arrays have the same dimensions or you will get odd results or errors.
;      
;      The values for this should be of the form 'C01', 'C02', ... 'C16'.
;    outFile: in, required, type=string
;      Set this required argument to a file you want to create on
;      disk for an animation of downloaded GOES data. This must be
;      a valid file type for the IDLffVideoWrite object.
;
; :Keywords:
;    OVERWRITE: in, optional, type=boolean, default=false
;      Set if you want to overwrite an existing output video file.
;
; :Author: Zachary Norman - GitHub: znorman17
;-
pro animateGOES, channels, outFile, OVERWRITE = overwrite
  compile_opt idl2
  ireset, /NO_PROMPT
  
  ;do some error catching
  if (channels eq !NULL) then begin
    message, 'channels not specified, required argument!'
  endif
  if (outFile eq !NULL) then begin
    message, 'outFile not specified, required!'
  endif
  if file_test(outFile) AND ~keyword_set(overwrite) then begin
    message, 'outFile specified, but file exists already. Specify OVERWRITE if you wish to replace.'
  endif
  
  ;get the directory that this code is located in
  thisdir = file_dirname(routine_filepath())
  
  ;read in an IDL logo to add onto the maps that are produced
  idlLogo = thisdir + path_sep() + 'img' + path_sep() + 'IDL_Icon_ColorLogo_Rev.png'
  if ~file_test(idlLogo) then begin
    message, 'IDL logo not found in img directory next to this code, errors will happen below if not present.'
  endif
  
  ;read in the image data
  idlPngDat = read_png(idlLogo)
  
  ;specify directory to search for data
  dirSearch = thisdir + path_sep() + 's3\noaa-goes16'
  
  if ~file_test(dirSearch) then begin
    message, 'GOES data directory not present in "./s3/noaa-goes16" as expected. Cannot search for data.
  endif
  
  ;get the number of channels that we want to process
  nChannels = n_elements(channels)
  
  ;validate
  if (nChannels ne 1) AND (nChannels ne 3) then begin
    message, 'The number of specified channels is not one or three, required!'
  endif
  
  ;only use upper case
  useChannels = strupcase(channels)
  
  ;search for GOES data
  print, 'Searching for data, may take a second for large datasets...'
  fileList = searchGOESData(dirSearch, useChannels)
  
  ;make sure we have files
  nFiles = n_elements(fileList)
  if (nFiles eq 0) then begin
    message, 'No files found for processing.'
  endif else begin
    print, '  Found files to process!'
    print
  endelse
  
  ;set video properties
  frames = nFiles  ;number of frames
  fps = 15         ;frames per second
  
  ;print information
  print, 'Processing ' + strtrim(frames,2) + ' GOES-16 scenes...'
  
  ;loop over each file
  foreach fileArr, fileList, i do begin
    ;print an update
    print, '  Processing frame ' + strtrim(i + 1,2) + ' of ' + strtrim(frames,2) + '...'
    
    ;loop over each potential file that we are going to process
    foreach file, fileArr, j do begin
      ;read the data from our file and get the time it was collected
      data = NCDF_Parse(file, /READ_DATA)

      ;get the radiance data for our file. Flip about Y axis because of the standards for remote sensing
      radiance = data['Rad','_DATA']
      
      ;init array to hold RGB data
      if (j eq 0) AND (nChannels eq 3) then begin
        dims = size(radiance, /DIMENSIONS)
        RGBdat = bytarr(dims[0], dims[1], 3)
      endif
      
      ;check how we need to process the data
      if (nChannels eq 3) then begin
        RGBdat[*,*,j] = hist_equal(radiance, PERCENT = 2)
      endif else begin
        RGBdat = hist_equal(radiance, PERCENT = 2)
      endelse
    endforeach

    ;if the first image, then we need to create the image and set up our map grid
    ;the grid is constant for each scene because the satellite is geostationary
    if (img eq !NULL) then begin
      ;extract the X and Y locations from the data and center of the scene
      ;we only need to do this once because the X and Y locations are always the same
      center_lon = data['geospatial_lat_lon_extent', $
        'geospatial_lon_nadir', '_DATA']

      xscale = data['x', 'scale_factor', '_DATA']
      xoffset = data['x', 'add_offset', '_DATA']
      x_radians = data['x', '_DATA']*DOUBLE(xscale) + xoffset

      yscale = data['y', 'scale_factor', '_DATA']
      yoffset = data['y', 'add_offset', '_DATA']
      y_radians = data['y', '_DATA']*DOUBLE(yscale) + yoffset
      
      ;create our image if we have RGB, else add color table
      if (nChannels eq 3) then begin
        img = image(RGBdat, x_radians, y_radians, $
          LIMIT = [15,-140, 55, -60], MARGIN = [0.1,0.02,0.08,0.02], $
          MAP_PROJECTION = 'GOES-R', GRID_UNITS = 'meters', $
          CENTER_LONGITUDE = center_lon, $
          DIMENSIONS = [1500,900], $
          TITLE = 'GOES-16 Level 1b Radiance, RGB Representation : ' + data['time_coverage_start', '_DATA'])
      endif else begin
        img = image(RGBdat, x_radians, y_radians, $
          RGB_TABLE = 15, $
          LIMIT = [15,-140, 55, -60], MARGIN = [0.1,0.02,0.08,0.02], $
          MAP_PROJECTION = 'GOES-R', GRID_UNITS = 'meters', $
          CENTER_LONGITUDE = center_lon, $
          DIMENSIONS = [1500,900], $
          TITLE = 'GOES-16 Level 1b Radiance, RGB Representation : ' + data['time_coverage_start', '_DATA'])        
      endelse
      
      ;customize our grid and add the countries and US vectors
      mg = img.MapGrid
      mg.label_position = 0
      mg.clip = 1
      mc = mapContinents(/COUNTRIES, COLOR = 'yellow')
      mc = mapContinents(/US, COLOR = 'yellow')
      
      ;add the image of the IDL logo and some small text
      imgIdl = image(idlPngDat, BACKGROUND_COLOR=!COLOR.gray, CURRENT = img,$
        POSITION = [0.83, 0.73, 0.99, 0.83])
      t = text(0.9, 0.78, 'Powered by', FONT_STYLE = 'bold', TARGET = img, FONT_SIZE = 14,$
        VERTICAL_ALIGNMENT = 0.5, ALIGNMENT = 0.5)
      t.position = [0.83, 0.84, 0.99, 0.88]
    endif else begin
      ;not the first image so we just need to update the data that is displayed
      ;and the title
      img.SetData, RGBdat, x_radians, y_radians
      img.TITLE = 'GOES-16 Level 1b Radiance, RGB Representation : ' + data['time_coverage_start', '_DATA']
    endelse

    ;initialize our video if this is our first frame
    if (i eq 0) then begin    
      ;get our image dimensions
      width = img.window.dimensions[0]
      height = img.window.dimensions[1]
      
      ; Create object and initialize video/audio streams
      oVid = IDLffVideoWrite(outFile)
      vidStream = oVid.AddVideoStream(width, height, fps)
    endif
    
    ;add content to our video stream
    time = oVid.Put(vidStream, img.copyWindow())
  endforeach

  ;close the video
  oVid.cleanup
  
  ;print update
  print, 'Finished!'
end

;main level program - example for how to call the code above

;get current directory
thisdir = file_dirname(routine_filepath())

;specify our output file
outFile = thisdir + path_sep() + 'goes-animation2.mp4'

;specify the channels that we want to search for
channels = ['C07', 'C08', 'C09']

;animate the CONUS GOES data that was downloaded
animateGOES, channels, outFile, /OVERWRITE
end