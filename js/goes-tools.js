//modules that we will use
var AWS = require('aws-sdk');
var moment = require('moment');
var mkdirp = require('mkdirp');
var fs = require('fs');
var Rx = require('rxjs/Rx');


//simple function that extracts a moment from the name of a 
//goes file to check the time if before/after a set date
exports.extractGoesDate = function (str) {
  //make sure we passed in our input 
  if (!str){
    throw 'str not passed in, required!';
  };

  //get the start of collection time
  var yearStr = str.substr(str.indexOf('_s') + 2, str.indexOf('_e')-(str.indexOf('_s') + 2));

  //extract pieces
  var hmsTime = yearStr.substr(7,2) + ':' + yearStr.substr(9,2) + ':' + 
    yearStr.substr(11,2) + '.'  + yearStr.substr(13,1);

  //make date to get the start of the ISO string
  //subtract a day because the year starts with day one
  var date = moment(yearStr.substr(0,4), 'YYYY').add(yearStr.substr(4,3)-1, 'day');

  //make total moment by making the ISO string
  return moment(date.format('YYYY-MM-DD') + 'T' + hmsTime + 'Z');
} 


exports.searchGOESData = function(t1, t2, product) {
  
  //specify the product type that we want to download
  product = 'ABI-L1b-RadC'; //CONUS - every 15 minutes
  //product = 'ABI-L1b-RadF'; //FULL DISK - every 5 minutes
  //product = 'ABI-L1b-RadM'; //MESOSCALE - every one minute each

  processingLevel = 'L1b'; // level 1b
  // processingLevel = 'L2'; // level 2

  // Create an S3 client
  // The credentials should be stored locally on disk based on
  // https://aws.amazon.com/sdk-for-node-js/
  var s3 = new AWS.S3();

  //create a downloader object
  var downloader = require('s3-download')(s3);

  // Create a bucket and upload something into it
  var bucketName = 'noaa-goes16';
  var maxKeys = 100;

  //init array to contain all of our results
  var resArr = [];

  //copy our first time so that we can process correctly
  useT1 = moment(t1);

  //do a simple loop to determine how many queries we will need to make
  var n = 0;
  while (t2.isAfter(useT1)) {
    n = n + 1;
    useT1.add(1, 'hour')
  }

  //copy our first time so that we can process correctly
  useT1 = moment(t1);

  //init counter for when we finish
  var nDone = 0;

  //use an observable to determine when we are done
  return Rx.Observable.fromPromise( new Promise( resolve => {
    //query all s3 buckets
    while (t2.isAfter(useT1)) {
      //get UTC time which is what GOES is collected using
      var utc = useT1.utc()

      //make parameters
      var params = {
        Bucket: bucketName,
        Delimiter: '',
        Prefix: product + '/' + utc.year() + '/' + utc.dayOfYear() +'/' + utc.hour() + '/OR_' + product + '-M3C01',
        MaxKeys: maxKeys
      }

      //query s3 for what files match our bucket
      s3.listObjectsV2(params, (err, data) => {
        if (err) {
          throw err
          //console.log(err, err.stack); // an error occurred
        } else {
          //console.log(data.Contents)
          data.Contents.forEach( bucketObject => {
            //get the date of the scene
            var sceneDate = exports.extractGoesDate(bucketObject.Key);

            //check if the date is within our acceptable times
            if (sceneDate.isAfter(t1) && sceneDate.isBefore(t2) ){
              // console.log(bucketObject);
              resArr.push(bucketObject);
            };
          });

          //update our counter
          nDone = nDone + 1;

          //check if we have finished
          if (nDone == n) {
            resolve(resArr);
          }
        };
      });

      //increment second time
      useT1.add(1, 'hour')
    } 

  }));
}


// //split the filepath to get the name and directory
// split = bucketObject.Key.split('/')
// fileName = split[split.length-1]    
// fileDir = bucketObject.Key.replace('/' + fileName, '')
// var params = {
//   Bucket:bucketName,        //required 
//   Key:bucketObject.Key            //required 
// }

// var sessionParams = {
//   concurrentStreams: 5,//default 5 
//   maxRetries: 3,//default 3 
//   totalObjectSize: bucketObject.Size//required size of object being downloaded 
// }

// var d = downloader.download(params,sessionParams);
// d.on('error',function(err){
// console.log('Error downloading file')
// console.log(err);
// });
// // // dat = size_of_part_downloaded 
// // d.on('part',function(dat){
// //    //console.log(dat);
// // });
// // d.on('downloaded',function(dat){
// //    console.log(dat);
// // });

// //build the directory we want to download to
// outdir = './s3/' + bucketName + '/' + fileDir
// if (!fs.existsSync(outdir)){
// mkdirp.sync(outdir)
// } 

// //make sure that our output file does not exist already
// outFile = outdir + '/' + fileName
// if (!fs.existsSync(outFile)){
// console.log('    Downloading...')        
// var w = fs.createWriteStream(outFile);
// d.pipe(w);
// } else {
// console.log('    File exists, skipping...')
// }
// console.log('')