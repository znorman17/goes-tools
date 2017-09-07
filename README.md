# GOES 16 Tools

Basic tool suite which wraps the AWS S3 SDK and uses a few other packages to search and download GOES data locally to a folder called "s3" which will be created in the same location as this package.

Note that this code does not handle all different cases for how might search for data in the GOES s3 bucket, but covers the basics.

## Usage

There are a handful of functions that are included in the `./js/goes-tools.js` file. They are all used together and here is a snippet of how to use them:


```javascript
// create search parameters
var params = new GT.GOESSearchParams;

//specify our search parameters
params.t1 = moment('2017-08-21 10:00:00');  // time 1 - for the time zone that you are currently in
params.t2 = moment('2017-08-21 14:00:00');  // time 2 - for the time zone that you are currently in
params.product = 'ABI-L1b-RadC';            // product
params.bands = ['C01'];                     // the name of each band you want to search for

//search and subscribe to async call using observables
GT.searchGOESData(params).subscribe((res) => {
  if (res.length !== 0) {
    GT.downloadGOESData(res).subscribe( (outFiles) =>{
      //print the downloaded files to the screen
      outFiles.forEach( (file) => {
        console.log(file);
      });
    });
  } else {
    console.log('No search results found!');
  };
});
```

See example.js for a complete example which you can run with

```
node example.js
```

## Directory Structure

To make the downloaded results more human-readable, the directory structure of anything that is downloaded will be of the form:

```
./s3/noaa-goes16/YYYY-MM-DD/hh/mm-ss.S
```

Where each letter after `./s3/noaa-goes16` represents:

- `Y` represents a four digit year
- `M` represents the two digit month of the year
- `D` is the two digit day of the month
- `h` is the UTC hour that the collection started
- `m` is the UTC minute that the collection started
- `s` is the UTC second that the collection started
- `S` is the UTC tenth of the second that the collection started 

This data structure was chosen so that you could more easily navigate any downloaded data and it also arranges the collections by the 16 bands that were collected. This way you don't have to worry about separating the original files into the separate collection start times.

## Installation

To install just run ```nmp install``` from a command prompt or terminal in this directory once you have node.js installed.

```
cd thisDirectory
npm install
```

### S3 Credentials

In order to use the tool you will need valid S3 credentials or nothing will work. Here is a link to how you can set up your credentials on your machine:

[https://aws.amazon.com/sdk-for-node-js/](#https://aws.amazon.com/sdk-for-node-js/)

Here is a link on how you can obtain credentials if you don't have them:

[https://aws.amazon.com/premiumsupport/knowledge-center/create-access-key/](#https://aws.amazon.com/premiumsupport/knowledge-center/create-access-key/)


## IDL Code

Once you download the data, you can use the provided IDL PRO code to create an animation of CONUS data (that is what it was made for). You will need IDL 8.6.1 for the code to run correctly because it uses the GOES-R projection which was recently added.

You will need to modify the directory that IDL searches for data as it is hard coded for the current dates in example.js.


## License 

Licensed under MIT, see LICENSE.txt for full details.