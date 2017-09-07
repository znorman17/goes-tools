// get all packages we need
var moment = require('moment');
var GT = require('./js/goes-tools.js');

// create search parameters
var params = new GT.GOESSearchParams;

//specify our search parameters
params.t1 = moment('2017-09-04 12:00:00');  // time 1 - for the time zone that you are currently in
params.t2 = moment('2017-09-04 12:10:00');  // time 2 - for the time zone that you are currently in
params.product = 'ABI-L1b-RadC';            // product
params.bands = ['C15'];                     // the name of each band you want to search for

//search and subscribe to async call
console.log('Querying avaiable GOES scenes...');
GT.searchGOESData(params).subscribe((res) => {
  if (res.length !== 0) {
    console.log('Attempting to download ' + res.length + ' GOES scene(s)...');
    GT.downloadGOESData(res).subscribe( (outFiles) =>{
      console.log('Files downloaded : ');
      //print the downloaded files to the screen
      outFiles.forEach( (file) => {
        console.log('  ' + file);
      });
    });
  } else {
    console.log('');    
    console.log('No search results found!');
  };
});
