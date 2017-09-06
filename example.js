// get all packages we need
var moment = require('moment');
var GT = require('./js/goes-tools.js')

//specify our first and second times for searching
var t1 = GT.extractGoesDate('OR_ABI-L1b-RadC-M3C01_G16_s20172331602189_e20172331604563_c20172331605005.nc');
var t2 = moment(t1).add(1, 'day');

//specify the product that we want to access
var product = 'ABI-L1b-RadC';

//search and subscribe to async call
console.log('Querying S3 for GOES scenes...');
GT.searchGOESData(t1, t2, product).subscribe((res) => {
  console.log(res.length);
});
