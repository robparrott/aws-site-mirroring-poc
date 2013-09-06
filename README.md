aws-site-mirroring-poc
======================

Proof of concept script for mirroring a website to S3 and CloudFront.

Currently mirrors a site and create an S3 bucket with the contents. Once static hosting is turned on with
that bucket, you can browse the site mirror on S3.


Requirements
------------

Shell script which uses the various typical command line tools from Linux/UNIX, plus the following commands:

- git
- wget 
- s3cmd
- 

Usage
-----

    ./bin/mirror.sh http://my.example.com
    
    
