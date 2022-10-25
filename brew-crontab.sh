#!/bin/bash -uo pipefail

#needed of this script is called from crontab
PATH="/usr/local/bin:/usr/local/sbin:$PATH"

#need to know current dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#parameters
DEBUG=false
BREW="brew"
LIST_PREFIX=brew-crontab
for i in "$@"
do
  case "$i" in
    options) #shows all available options
      grep ') #' $BASH_SOURCE \
        | grep -v grep \
        | sed 's:)::g' \
        | column -t -s\#
      exit
    ;;
    -x) #turns on the -x bash option
      set -x
    ;;
    debug) #shows what is being done and the value of some variables
      DEBUG=true
    ;;
    echo) #shows which commands would have been issued, but don't
      BREW="echo brew"
    ;;
    list-prefix) #sets the prefix of the packages.list files, defaults to brew-crontab
      LIST_PREFIX=${i/list-prefix}
    ;;
    help)
      echo "\
$BASH_SOURCE [ ... ]

Keeps brew packages up to date. The packages are kept in lists with names $LIST_PREFIX.packages\*.list. The lists are loaded alphabetically.

These lists contain one package name per line, comments are allowed after '#' and with any necessary install argument following, e.g.:
curl
gnuplot --with-x11 --with-pdflib-lite --with-wxmac
rsync #OSX's rsync is out of date

This script considers 3 lists:
- brew-crontab.packages.list: nothing special about this list
- brew-crontab.packages-xcode.list: ensures xcode is installed; if that is not possible, then none of these packages are installed.
- brew-crontab.packages-keep-outdated.list: packages here are not to be updated

All lists should reside in the same directory as this script ($DIR).

Optional input arguments are:"
      $BASH_SOURCE options
      exit
    ;;
  esac
done

#check if command line tools is installed
$DEBUG || ( xcode-select -p &> /dev/null || xcode-select --install )

#check if BREW is installed
$DEBUG || ( brew -v &> /dev/null || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" )

for PACKAGES_FILE in $(find "$DIR" -name $LIST_PREFIX.packages\*.list | sort -u)
do
  $DEBUG && echo "PACKAGES_FILE: $PACKAGES_FILE"
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
    #get package version, try cask first, fallback to non-cask
    PKG_VERSION=$(
      $BREW ls --cask --version ${PKG_SHORT/homebrew\/cask\//} 2> /dev/null \
      || $BREW ls --version $PKG_SHORT 2> /dev/null
    )
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
  FB=$($BREW $i) || exit $?
  FB=$(echo "$FB" | grep -v 'No Casks to upgrade' || true)
  [ -z "$FB" ] || echo -e "brew $i:\n$FB"
done
for i in upgrade outdated
do
  $DEBUG && echo "==== Issuing brew $i --cask ===="
  FB=$($BREW $i --cask) || exit $?
  [ -z "$FB" ] || echo -e "brew $i --cask:\n$FB"
done

if [ -s "$DIR/$LIST_PREFIX.packages-keep-outdated.list" ]
then
  KEEP=$(cat $DIR/$LIST_PREFIX.packages-keep-outdated.list)
  for i in $(brew list --formula)
  do
    if [[ "${KEEP/$i/}" == "$KEEP" ]]
    then
      $DEBUG && echo "==== Issuing brew cleanup $i ===="
      FB=$($BREW cleanup $i) || exit $?
      [ -z "$FB" ] || echo -e "brew cleanup $i:\n$FB"
    else
      $DEBUG && echo "==== Not cleaning up $i ===="
    fi
  done
fi

#call the doctor
$DEBUG && echo "==== Issuing brew doctor ===="
FB=$($BREW doctor) || echo "$FB"
