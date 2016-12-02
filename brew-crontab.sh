#!/bin/bash -u

#parameters
if [[ ! "${@/debug/}" == "$@" ]]
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
[ $DEBUG == false ] && ( xcode-select -p &> /dev/null || xcode-select --install )

#check if BREW is installed
[ $DEBUG == false ] && ( brew -v &> /dev/null || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" )


for PACKAGES_FILE in $(find "$DIR" -name brew.packages\*.list)
do
  #assume this list of packages is to be installed
  INSTALL_MORE_PACKAGES=true
  #check if particular requirements of some list of packages are met
  if [[ ! "${PACKAGES_FILE/xcode/}" == "$PACKAGES_FILE" ]]
  then
    #check if xcode is installed
    xcode-select -v &> /dev/null || INSTALL_MORE_PACKAGES=false
  fi
  #add more package list requirements here

  #check if all requirements are met, if not skip this list
  $INSTALL_MORE_PACKAGES || continue
  #proceed with installation
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
    if [ -z "`brew ls --version $PKG_SHORT 2> /dev/null`" ]
    then
      [ $DEBUG == true ] && echo Installing $PKG_SHORT
      $BREW install $PKG || exit $?
    else
      [ $DEBUG == true ] && echo Package already installed: $PKG_SHORT
    fi
  done
done

#update formulas
$BREW update > /dev/null || exit $?

#more stuff to do
# for i in upgrade cleanup missing outdated
for i in upgrade missing outdated
do
  FB=`$BREW $i` || exit $?
  [ -z "$FB" ] || echo -e "brew $i:\n$FB"
done

#call the doctor
FB=`$BREW doctor` || echo $FB
