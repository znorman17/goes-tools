pro animateGoes
  compile_opt idl2
  ireset, /NO_PROMPT
  
  ;get the directory that this image is located in
  thisdir = file_dirname(((scope_traceback(/STRUCT))[-1]).FILENAME)
  
  ;specify our output file
  outFile = thisdir + path_sep() + 'goes-animation.mp4'
  
  ;specify directory to search for data
  ;CHANGE THIS TO MATCH YOUR DIRECTORY OF DATA THAT WAS DOWNLOADED
  dirSearch = thisdir + path_sep()  + 's3\noaa-goes16\ABI-L1b-RadC\2017\233'
  
  ;search for files
  files = file_search(dirSearch, '*.nc', COUNT = nFiles)
  
  ;make sure we found files
  if (nFiles eq 0) then begin
    message, 'No files found for processing'
  endif
  
  ;set video properties
  frames = nFiles  ;number of frames
  fps = 15         ;frames per second
  
  ;print information
  print, 'Processing ' + strtrim(frames,2) + ' GOES-16 scenes...'
  
  ;loop over each file
  foreach file, files, i do begin
    ;print an update
    print, '  processing frame ' + strtrim(i + 1,2) + ' of ' + strtrim(frames,2) + '...'
    
    ;read the data from our file and get the time it was collected
    data = NCDF_Parse(file, /READ_DATA)
    time = data['time_coverage_start', '_DATA']

    ;get the radiance data for our file. Flip about Y axis because of the standards for remote sensing
    radiance = data['Rad','_DATA']

    ;if the first image, then we need to create the image and set up our map grid
    if (i eq 0) then begin
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
      
      ;create our image
      img = image(radiance, x_radians, y_radians, $
        RGB_TABLE = 15, $
        LIMIT = [15,-140, 55, -60],MARGIN = [0.1,0.02,0.08,0.02], $
        MAP_PROJECTION = 'GOES-R', GRID_UNITS = 'meters', $
        CENTER_LONGITUDE = center_lon, $
        DIMENSIONS = [500,300], $
        TITLE = 'GOES-16 Level 1b Radiance: ' + time)
      
      ;customize our grid and add the countries and US vectors
      mg = img.MapGrid
      mg.label_position = 0
      mg.clip = 1
      mc = mapContinents(/COUNTRIES)
      mc = mapContinents(/US)
    endif else begin
      ;not the first image so we just need to update the data that is displayed
      ;and the title
      img.SetData, hist_equal(radiance)
      img.TITLE = 'GOES-16 Level 1b Radiance: ' + time
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