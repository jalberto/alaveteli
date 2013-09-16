#!/bin/sh

# Set this to the version we want to check out - for developing the
# script, make this the remote-tracking branch corresponding to the
# dev branch:
VERSION=origin/install-script

PARENT_SCRIPT_URL=https://github.com/mysociety/commonlib/blob/master/bin/install-site.sh

misuse() {
  echo The variable $1 was not defined, and it should be.
  echo This script should not be run directly - instead, please run:
  echo   $PARENT_SCRIPT_URL
  exit 1
}

# Strictly speaking we don't need to check all of these, but it might
# catch some errors made when changing install-site.sh

[ -z "$DIRECTORY" ] && misuse DIRECTORY
[ -z "$UNIX_USER" ] && misuse UNIX_USER
[ -z "$REPOSITORY" ] && misuse REPOSITORY
[ -z "$REPOSITORY_URL" ] && misuse REPOSITORY_URL
[ -z "$BRANCH" ] && misuse BRANCH
[ -z "$SITE" ] && misuse SITE
[ -z "$DEFAULT_SERVER" ] && misuse DEFAULT_SERVER
[ -z "$HOST" ] && misuse HOST
[ -z "$DISTRIBUTION" ] && misuse DISTRIBUTION
[ -z "$VERSION" ] && misuse VERSION

install_nginx

# XXX FIXME: decide on Exim vs Postfix

# Check out the current released version
su -l -c "cd '$REPOSITORY' && git checkout '$VERSION'" "$UNIX_USER"

install_website_packages

notice_msg "FIXME: complete this script..."
