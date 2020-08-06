#!/bin/bash -uo pipefail

#parameters
DEBUG=false
BREW="brew"
for i in "$@"
do
  case "$i" in
    debug)
      DEBUG=true
    ;;
    echo)
      BREW="echo brew"
    ;;
    -x)
      set -x
    ;;
  esac
done

#needed of this script is called from crontab
PATH="/usr/local/bin:/usr/local/sbin:$PATH"

#need to know current dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#check if command line tools is installed
$DEBUG || ( xcode-select -p &> /dev/null || xcode-select --install )

#check if BREW is installed
$DEBUG || ( brew -v &> /dev/null || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" )

for PACKAGES_FILE in $(find "$DIR" -name brew.packages\*.list | sort -u)
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
    PKG_SHORT=${PKG%% *}
    #check if this is a cask
    if [[ ! "${PKG_SHORT/cask}" == "$PKG_SHORT" ]]
    then
      PKG_VERSION=$($BREW cask ls --versions $PKG_SHORT 2> /dev/null)
    else
      PKG_VERSION=$($BREW ls --versions $PKG_SHORT 2> /dev/null)
    fi
    if [ -z "$PKG_VERSION" ]
    then
      $DEBUG && echo "==== Installing $PKG_SHORT ===="
      $BREW install $PKG || exit $?
    else
      $DEBUG && echo "==== Package already installed: $PKG_VERSION ===="
    fi
  done
done

#update formulas
$BREW update > /dev/null || exit $?

#more stuff to do
for i in upgrade missing outdated
do
  $DEBUG && echo "==== Issuing brew $i ===="
  FB=$($BREW $i | grep -v 'No Casks to upgrade') || exit $?
  [ -z "$FB" ] || echo -e "brew $i:\n$FB"
done
for i in  outdated
do
  $DEBUG && echo "==== Issuing brew cask $i ===="
  FB=$($BREW cask $i) || exit $?
  [ -z "$FB" ] || echo -e "brew cask $i:\n$FB"
done

KEEP=$(cat $(find "$DIR" -name brew.packages-keep-outdated.list))
for i in $(brew list)
do
  if [[ "${KEEP/$i/}" == "$KEEP" ]]
  then
    $DEBUG && echo "==== Issuing brew cleanup $i ===="
    FB=$($BREW cleanup $i) || exit $?
    [ -z "$FB" ] || echo -e "brew cleanup $i:\n$FB"
  fi
done

#call the doctor
$DEBUG && echo "==== Issuing brew doctor ===="
FB=$($BREW doctor) || echo "$FB"
