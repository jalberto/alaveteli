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
[ -z "$DEVELOPMENT_INSTALL" ] && misuse DEVELOPMENT_INSTALL
[ -z "$BIN_DIRECTORY" ] && misuse BIN_DIRECTORY

update_mysociety_apt_sources

# XXX FIXME: decide on Exim vs Postfix

if [ ! "$DEVELOPMENT_INSTALL" = true ]; then
    install_nginx
    add_website_to_nginx
    # Check out the current released version
    su -l -c "cd '$REPOSITORY' && git checkout '$VERSION'" "$UNIX_USER"
fi

install_postfix

install_website_packages

# Make the PostgreSQL user a superuser to avoid the irritating error:
#   PG::Error: ERROR:  permission denied: "RI_ConstraintTrigger_16564" is a system trigger
add_postgresql_user --superuser

export DEVELOPMENT_INSTALL
su -c "$BIN_DIRECTORY/install-as-user '$UNIX_USER' '$HOST' '$DIRECTORY'" "$UNIX_USER"

if [ ! "$DEVELOPMENT_INSTALL" = true ]; then
    install_sysvinit_script
fi

notice_msg "FIXME: set up the MTA as well"; echo
notice_msg "FIXME: set up cron jobs"; echo
notice_msg "FIXME: set up Varnish as well"; echo
