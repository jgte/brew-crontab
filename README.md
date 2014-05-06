brew-crontab
============

This is a simple script that keeps brew updated and healthy, suitable for crontab. Stick it in a cloud folder, add it to the crontab of all your machines and keep your brew packages up to date and consistent.

List files
----------

The `brew-crontab.packages.list` and `brew-crontab.packages-xcode.list` files contain the list of the packages to be installed. These files are assumed to live in the same directory as `brew-contrab.sh`. If they cannot be found, the corresponding packages are not installed. The packages in `brew-crontab.packages-xcode.list` are only installed if the completed xcode is present in the system.
