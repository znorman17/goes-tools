//modules that we will use
var AWS = require('aws-sdk');
var moment = require('moment');
var mkdirp = require('mkdirp');
var fs = require('fs');
var Rx = require('rxjs/Rx');
var ProgressBar = require('progress');

//global buckt name for the goes data
var bucketName = 'noaa-goes16';

//create a class for search parameters
exports.GOESSearchParams = function () {
  //init search times
  this.t1 = moment();
  this.t2 = moment();

  //specify the product type that we want to download
  this.product = 'ABI-L1b-RadC'; // 'ABI-L1b-RadC' | 'ABI-L1b-RadF' | 'ABI-L1b-RadM';  CONUS, Full-Disk, Mesoscale

  this.processingLevel = ''//'L1b' | 'L2'; // level 1b

  //init an array with the bands we want to download
  this.bands = ['C01'];
}


//simple function that extracts a moment from the name of a 
//goes file to check the time if before/after a set date
exports.extractGOESDate = function (str) {
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


//simple function to search for GOES data
exports.searchGOESData = function(searchParams) {
  //make sure we passed it in
  if (!searchParams) {
    throw 'searchParams has not been passed in. Must be GOESSearchParams class.'
  }

  //extract some variables from our search parameters
  var t1 = searchParams.t1;
  var t2 = searchParams.t2
  var bands = searchParams.bands;
  var product = searchParams.product;

  //make sure we have bands
  if (bands.length == 0) {
    throw 'No GOES bands passed as input. Should be of the form "C01", "C02", ... "C16"'
  }

  // Create an S3 client
  var s3 = new AWS.S3();

  // Create a bucket and upload something into it
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

  //increment total by the number of bands we want to search for
  n = n*bands.length;

  //initialize our progress bar
  var bar = new ProgressBar('  [ :bar ] Approx. time remaining = :eta (s)', { total: n + 1, width: 20});  

  //copy our first time so that we can process correctly
  useT1 = moment(t1);

  //init counter for when we finish
  var nDone = 0;

  //use an observable to determine when we are done
  return Rx.Observable.fromPromise( new Promise( resolve => {
    //query all s3 buckets for band
    while (t2.isAfter(useT1)) {
      //get UTC time which is what GOES is collected using
      var utc = useT1.utc()

      //loop over each band and query for each specific file
      bands.forEach( (band) => {
        //make parameters
        var s3params = {
          Bucket: bucketName,
          Delimiter: '',
          Prefix: product + '/' + utc.year() + '/' + utc.dayOfYear() +'/' + utc.hour() + '/OR_' + product + '-M3' + band,
          MaxKeys: maxKeys
        }

        //query s3 for what files match our bucket
        s3.listObjectsV2(s3params, (err, data) => {
          if (err) {
            throw err
            //console.log(err, err.stack); // an error occurred
          } else {
            //console.log(data.Contents)
            data.Contents.forEach( (bucketObject) => {
              //get the date of the scene
              var sceneDate = exports.extractGOESDate(bucketObject.Key);

              //check if the date is within our acceptable times
              if (sceneDate.isAfter(t1) && sceneDate.isBefore(t2) ){
                // console.log(bucketObject);
                resArr.push(bucketObject);
              };
            });

            //update our counter
            nDone = nDone + 1;

            //update our progress bar
            bar.tick();

            //check if we have finished
            if (nDone == n) {
              resolve(resArr);
            };
          };
        });
      });

      //increment second time
      useT1.add(1, 'hour');
    } 
  }));
}




// function to download the scenes that we just searched for
exports.downloadGOESData = function (searchResults) {
  //make sure we passed something in
  if (!searchResults) {
    throw 'searchResults has not been specified, required array of search results!';
  };

  // Create an S3 client
  var s3 = new AWS.S3();
  
  //create a downloader object
  var downloader = require('s3-download')(s3);

  //init array to save the output filenames
  var outFiles = [];

  //init counter for when we are finished
  var nDone = 0;

  //initialize our progress bar
  var bar = new ProgressBar('  [ :bar ] Approx. time remaining = :eta (s)', { total: searchResults.length + 1, width: 20});    

  //use an observable to determine when we are done
  return Rx.Observable.fromPromise( new Promise( resolve => {
    //loop over our array of objects
    searchResults.forEach( (bucketObject) => {
      //split the S3 key to get the name and directory
      var split = bucketObject.Key.split('/');
      var fileName = split[split.length-1];
      var fileDir = bucketObject.Key.replace('/' + fileName, '');

      //s3 object information
      var params = {
        Bucket:bucketName,        //required 
        Key:bucketObject.Key            //required 
      };

      //parameters for downloading data
      var sessionParams = {
        concurrentStreams: 5,//default 5 
        maxRetries: 3,//default 3 
        totalObjectSize: bucketObject.Size//required size of object being downloaded 
      };

      //build the directory we want to download to
      outdir = './s3/' + bucketName + '/' + fileDir;
      if (!fs.existsSync(outdir)){
        mkdirp.sync(outdir);
      };

      //make sure that our output file does not exist already
      outFile = outdir + '/' + fileName;

      //create a downloader object to get the files we found
      var d = downloader.download(params, sessionParams);

      //error callback
      d.on('error', (err) => {
        bar.interrupt('Error downloading file, skipping key : ' + bucketObject.Key);

        //increment progress
        bar.tick();
        
        //update our counter
        nDone = nDone + 1;

        //check if we have finished
        if (nDone == searchResults.length) {
          resolve(outFiles);
        };
      });

      //finished callback
      d.on('downloaded', (dat) => {
        //increment progress
        bar.tick();

        //update our counter
        nDone = nDone + 1;

        //save our file
        outFiles.push(outFile);

        //check if we have finished
        if (nDone == searchResults.length) {
          resolve(outFiles);
        };
      });

      //only download our file if it does not exist
      if (!fs.existsSync(outFile)){
        //open download stream to get files
        var w = fs.createWriteStream(outFile);

        //pipe data to file on disk
        d.pipe(w);
      } else {
        //update the bar
        bar.tick()

        //update our counter
        nDone = nDone + 1;
        
        //save our file even though we didnt download bc it is on disk
        outFiles.push(outFile);
        
        //check if we have finished
        if (nDone == searchResults.length) {
          resolve(outFiles);
        };
      };
    });
  }));
}


