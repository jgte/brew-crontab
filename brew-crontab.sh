#!/bin/bash -u

#parameters
if [[ ! "${@/--debug/}" == "$@" ]]
then
  DEBUG=true
else
  DEBUG=false
fi

#needed of this script is called from crontab
PATH="/usr/local/bin:/usr/local/sbin:$PATH"

#need to know current dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#enforce debug mode
if [ $DEBUG == true ]
then
  BREW="echo brew"
else
  BREW="brew"
fi

#check if command line tools is installed
[ $DEBUG == false ] && ( xcode-select -p > /dev/null || xcode-select --install )

#check if BREW is installed
[ $DEBUG == false ] && ( brew -v > /dev/null || ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go/install)" )

PACKAGES_FILE="$DIR/brew-crontab.packages.list"
if [ -e "$PACKAGES_FILE" ]
then
  IFS_SAVE=$IFS
  IFS=$'\r\n'; GLOBIGNORE='*';
  PACKAGES=(`grep -v ^# "$PACKAGES_FILE" `)
  IFS=$IFS_SAVE
  #check if all packages are installed
  for ((i = 0 ; i < ${#PACKAGES[@]} ; i++))
  do
    #get this package name
    PKG=${PACKAGES[i]%#*}
    #skip lines that are only comments
    [ -z "$PKG" ] && continue
    #remove arguments from package name
    PKG_SHORT=${PKG% .*}
    if [ -z "`brew ls --versions $PKG_SHORT`" ]
    then
      [ $DEBUG == true ] && echo Installing $PKG_SHORT
      $BREW install $PKG || exit $?
    else
      [ $DEBUG == true ] && echo Package already installed: $PKG_SHORT
    fi
  done
else
  [ $DEBUG == true ] && echo "WARNING: Could not find packages file '$PACKAGES_FILE'."
fi

PACKAGES_FILE="$DIR/brew-crontab.packages-xcode.list"
if [ -e "$PACKAGES_FILE" ]
then
  #check if full xcode is installed
  xcodebuild -v &> /dev/null && INSTALL_MORE_PACKAGES=true || INSTALL_MORE_PACKAGES=false
  if [ $INSTALL_MORE_PACKAGES == true ]
  then
    IFS_SAVE=$IFS
    IFS=$'\r\n'; GLOBIGNORE='*';
    PACKAGES=(`grep -v ^# "$PACKAGES_FILE" `)
    IFS=$IFS_SAVE
    #check if all packages are installed
    for ((i = 0 ; i < ${#PACKAGES[@]} ; i++))
    do
      #get this package name
      PKG=${PACKAGES[i]%#*}
      #skip lines that are only comments
      [ -z "$PKG" ] && continue
      #remove arguments from package name
      PKG_SHORT=${PKG% .*}
      if [ -z "`brew ls --versions $PKG_SHORT`" ]
      then
        [ $DEBUG == true ] && echo Installing $PKG_SHORT
        $BREW install $PKG || exit $?
      else
        [ $DEBUG == true ] && echo Package already installed: $PKG_SHORT
      fi
    done
  fi
fi

#update formulas
$BREW update > /dev/null || exit $?

#more stuff to do
# for i in upgrade cleanup missing outdated
for i in "upgrade --all" missing outdated
do
  FB=`$BREW $i` || exit $?
  [ -z "$FB" ] || echo -e "brew $i:\n$FB"
done

#call the doctor
FB=`$BREW doctor` || echo $FB
