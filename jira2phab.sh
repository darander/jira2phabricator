## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## 
## JIRA to Phabricator migration script
##
## Addition mady by Anders Darander
##
## Copyright (C) 2014 met.no
##
##  Contact information:
##  Norwegian Meteorological Institute
##  Box 43 Blindern
##  0313 OSLO
##  NORWAY
##  E-mail: @met.no
##
##  This is free software; you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation; either version 2 of the License, or
##  (at your option) any later version.
##
## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#!/bin/bash

CERT="ENTER-CONDUIT-CERTIFICATE"
PHAB="ENTER-PHAB-URL"
USER="ENTER-USER-NAME"
PROJ="ENTER-PROJECT-NAME"
ARCKEY="ENTER-ARC-KEY"
lbls="\nLabels: "
vers="\nAffects versions: "
fixvers="\nFix version: "

JIRA="ENTER-JIRA-URL/secure/attachment/"

# Testmode lets us just check things...
#TESTMODE="echo"
ARCYON="$TESTMODE arcyon"
ARC="$TESTMODE arc"

read_dom () {
  local IFS=\>
  read -d \< ENTITY CONTENT
  local ret=$?
  TAG_NAME=${ENTITY%% *}
  ATTRIBUTES=${ENTITY#* }
  return $ret
}

parse_dom () {
  if [[ $TAG_NAME = "title" ]] ; then
    eval local $ATTRIBUTES
    #echo "Title: $CONTENT"
    echo $ARCYON task-create --uri $PHAB --user $USER --cert $CERT $reporter $owner --projects "$PROJ" --format-id "$CONTENT"
   TID=`$ARCYON task-create --uri $PHAB --user $USER --cert $CERT $reporter $owner --projects "$PROJ" --format-id "$CONTENT"`
   echo TID $TID
  elif [[ $TAG_NAME = "reporter" ]] ; then
    eval local $ATTRIBUTES
    reporter="--act-as-user $username"
    reportername=$username
  elif [[ $TAG_NAME = "attachment" ]] ; then
    eval local $ATTRIBUTES
    mkdir -p tempdl
    wgetname=`echo $name | sed -e 's/ /%20/g'`
    wget $JIRA/$id/$wgetname -O "tempdl/$name"
    echo $ARC upload --conduit-token=$ARCKEY --conduit-uri=$PHAB "tempdl/$name"
    FID=`$ARC upload --conduit-token=$ARCKEY --conduit-uri=$PHAB "tempdl/$name" |grep "$name" | cut -d ' ' -f 3`
    $ARCYON task-update --uri $PHAB --user $USER --cert $CERT --act-as-user $author $owner $TID --comment "On $created, $author uploaded $name as $FID"
    [[ -n "$FID" ]] && rm "tempdl/$name"
  elif [[ $TAG_NAME = "description" ]] ; then
    eval local $ATTRIBUTES
    desc=$(echo $CONTENT | sed 's/&lt;br\/&gt;/\\n/g' | sed 's/&lt;\/p&gt;/\\n\\n/g' | sed 's/&lt;p&gt;//g' )
  elif [[ $TAG_NAME = "customfieldname" ]] ; then
    # This is used to grab a custom field Requirement
    eval local $ATTRIBUTES
    if [[ $CONTENT = "Requirement" ]] ; then
	    REQ="req"
    fi
  elif [[ $TAG_NAME = "assignee" ]] ; then
    eval local $ATTRIBUTES
    owner="--owner $username"
  elif [[ $TAG_NAME = "label" ]] ; then
    eval local $ATTRIBUTES
    [[ -n "$CONTENT" ]] && lbls="$lbls $CONTENT,"
  elif [[ $TAG_NAME = "status" ]] ; then
    eval local $ATTRIBUTES
    echo status id=$id desc=$description
    if [ $id = "1" ] ; then
      phabstat="Open"
      phabstatdesc=$description
    elif [ $id = "4" ] ; then
      phabstat="Open"
      phabstatdesc=$description
    elif [ $id = "5" ] ; then
      phabstat="Resolved"
      phabstatdesc=$description
    elif [ $id = "6" ]; then
      phabstat="Resolved"
      phabstatdesc=$description
    elif [ -n "$TESTMODE" ] ; then
      # When running in TESTMODE, error out if id is unknown
      echo Unknown status: id=$id, desc=$description
      phabstat="Unknown"
      phabstatdesc="Whatever"
      exit 1
    fi
    echo status phabstat=$phabstat phabstatdesc=$phabstatdesc
  elif [[ $TAG_NAME = "resolved" ]] ; then
    eval local $ATTRIBUTES
    phabstatres=$CONTENT
  elif [[ $TAG_NAME = "resolution" ]] ; then
    eval local $ATTRIBUTES
    phabstatresolution=$CONTENT
  elif [[ $TAG_NAME = "created" ]] ; then
    eval local $ATTRIBUTES
    taskcreated=$CONTENT
  elif [[ $TAG_NAME = "/customfieldvalues" ]] ; then
	  REQ="false"
  elif [[ $TAG_NAME = "version" ]] ; then
    eval local $ATTRIBUTES
    [[ -n "$CONTENT" ]] && vers="$vers $CONTENT,"
  elif [[ $TAG_NAME = "fixVersion" ]] ; then
    eval local $ATTRIBUTES
    [[ -n "$CONTENT" ]] && fixvers="$fixvers $CONTENT,"
  elif [[ $TAG_NAME = "comment" ]] ; then
    eval local $ATTRIBUTES
    ENTRY="On $created, @$author wrote:\n\n$CONTENT"
    com=$(echo $ENTRY | sed 's/&lt;br\/&gt;/\\n/g' | sed 's/&lt;\/p&gt;/\\n\\n/g' | sed 's/&lt;p&gt;//g' | sed 's/&lt;[^>]\+&quot;&gt;//g' | sed 's/&lt;\/a&gt;//g' | sed 's/&apos;/\"/g' )
    #echo -e $com
    $ARCYON task-update --uri $PHAB --user $USER --cert $CERT --act-as-user $author $owner $TID --comment "$(echo -e $com)"
  elif [[ $TAG_NAME = "/item" ]] ; then
    if [[ $lbls != "\nLabels: " ]] ; then
      desc=$(echo "$desc$lbls" | sed 's/,\+$//' )
    fi
    if [[ $vers != "\nAffects versions: " ]] ; then
      desc=$(echo "$desc$vers" | sed 's/,\+$//' )
    fi
    if [[ $fixvers != "\nFix version: " ]] ; then
      desc=$(echo "$desc$fixvers" | sed 's/,\+$//' )
    fi
    echo -e "Description:\n$desc"
    #Reset requirements string at the end of the description
    lbls="\nLabels: "
    vers="\nAffects versions: "
    fixvers="\nFix version: "
    desc="On $taskcreated, @$reportername created task:\n\n $desc"
    $ARCYON task-update --uri $PHAB --user $USER --cert $CERT  --act-as-user "$author" $owner $TID --description "$(echo -e $desc)"
    echo $ARCYON task-update --uri $PHAB --user $USER --cert $CERT  --act-as-user "$author" $owner $TID --description "$(echo -e $desc)"

    if [ -n "$phabstat" ] ; then
      echo Final status $phabstat
      desc="On $phabstatres, status was set to $phabstatresolution \n\n$phabstatdesc"
      $ARC close --conduit-uri=$PHAB --conduit-token=$ARCKEY $TID --status=$phabstat -m "$(echo -e $desc)"
      echo $ARC close --conduit-uri=$PHAB --conduit-token=$ARCKEY $TID --status=$phabstat -m "On $phabstatres, status was set to $phabstatresolution \n\n$phabstatdesc"
    fi
  fi
}

while read_dom; do
  parse_dom
done
