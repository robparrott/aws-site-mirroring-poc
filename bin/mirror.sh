#!/bin/bash

WEBSITE=$1

LOGFILE=mirror.log
WGET_OPTIONS=" -r -E -nc -nH --tries=5 -o $LOGFILE "

function website_to_hostname
{
  local hostname=$( echo $1 | sed 's#http.*//##' | sed 's#/.*##' )
  echo $hostname
}

function mime_type 
{
  file --mime-type $1 | awk '{print $2}'
}

function query_url_files
{
  find . -name '*\?*' -type f
}

function setup_bucket
{
  local website=${1}
  local bucket=$( website_to_hostname ${website} )
  buck=$( aws s3 ls | grep " ${bucket}$" )
  if [ "x${buck}" = x ]; then 
     aws s3 mb s3://${bucket} || /bin/true
  fi
}

function sync_bucket
{
  local website=${1}
  local bucket=$( website_to_hostname ${website} )
  local files=$( get_changed_files )
  for file in $files; do
    file=$(  echo $file | sed 's#^./##' )
    local site=$( echo $file | awk -F/ '{print $1}' )
    local obj_name=$( echo ${file} |  sed 's/\/__content__$//' )    
    mime_type=$( mime_type "$file"  )
    s3cmd_opts="  --acl-public --no-preserve --mime-type=${mime_type}" #--add-header='Cache-Control:public, max-age=86400' 
    cmd="s3cmd ${s3cmd_opts} put ${file} s3://${bucket}/${obj_name} "
    echo $cmd
    $cmd
  done 
}

function setup_data_dir
{
  local website=${1} 
  local bucket=$( website_to_hostname ${website} )
  local data_dir=./data/${bucket}

  [ -d ${data_dir} ] || mkdir -p ${data_dir}
  cd ${data_dir}
  
  if ! [ -d .git ]; then
    git init > /dev/null
    echo "This is an automatically generated mirror of the ${1} site, captured as a git repository." >> README.txt
    git add README.txt > /dev/null
    git commit -m "Initialized empty mirror repository for site ${1}" > /dev/null
  fi  
  pwd
  cd -
}

function mirror_site
{
  local website=${1}
  local hostname=$( website_to_hostname $website )
  local BEGIN_DATE=$( date )
  wget ${WGET_OPTIONS} ${website} 
  local END_DATE=$( date )

  # Find any pages that are named the same as dirs, and rename them accordingly

  index_pages=$( find . -name \*.1.html -type f )
  for page in $index_pages; do                                                                                                                                                                 
    base=$( echo ${page} | sed 's/\.1\.html$//' )
    mv ${page} ${base}/__content__
  done   

  # Loop through pages and make copies with different extensions, if needed
  html_files=$( find . -name \*.html -type f )
  for html_file in $html_files; do 
    short_name=$( echo $html_file | sed 's/\.html$//' )
    
    if [ -d $short_name ]; then
      cp ${html_file} ${short_name}/__content__
    else
      cp ${html_file} ${short_name}
    fi
  done
 
  
  # make a non-query version of any stupid files
  qfiles=$( query_url_files )
  echo Query files .... $qfiles

  for $qf in ${qfiles}; do
    short_name=$( echo $qf | sed 's/\?.*$//' )
    if ! [ -f "$short_name" ]; then
      cp "$qf" "$short_name"
    fi
  done
       
  # edit lihks to remove absolute refs to this site
  target_files=$( grep -H -R =\"http://${hostname}/ * | awk -F: '{print $1}' | sort -u   )
  for target in $target_files; do 
    perl -i -p -e "s#=\"http://${hostname}/#=\"/#g" ${target}
  done     

  git add *
  git commit -m "Mirror of site ${website} begun on ${BEGIN_DATE} and ending ${END_DATE}" >> $LOGFILE
} 

function get_changed_files
{
#  previous_hash=$( git log | grep "^commit " | sed 's/commit *//' | head -2 | tail -1 )
#  changed_files=$( git diff ${previous_hash} HEAD |  grep "^diff --git" | awk '{print $3}' | sed 's#a/##' )
  changed_files=$( find . -type f  | grep -v .git/ )
  echo $changed_files
}

setup_bucket ${WEBSITE}
DATA_DIR=$( setup_data_dir ${WEBSITE} )
cd ${DATA_DIR}
pwd

mirror_site ${WEBSITE}
sync_bucket ${WEBSITE} 

#echo $FILES

#publish_site_mirror ${BUCKET}

 
