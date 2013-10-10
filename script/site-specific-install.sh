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

if [ ! "$DEVELOPMENT_INSTALL" = true ]; then
    install_nginx
    add_website_to_nginx
    # Check out the current released version
    su -l -c "cd '$REPOSITORY' && git checkout '$VERSION'" "$UNIX_USER"
fi

install_postfix

# Now there's quite a bit of Postfix configuration that we need to
# make sure is present:

ensure_line_present() {
    MATCH_RE="$1"
    REQUIRED_LINE="$2"
    FILE="$3"
    if [ -f "$FILE" ]
    then
        if egrep "$MATCH_RE" "$FILE" > /dev/null
        then
            sed -r -i -e "s,$MATCH_RE,$REQUIRED_LINE," "$FILE"
        else
            TMP_FILE=$(mktemp)
            echo "$REQUIRED_LINE" > $TMP_FILE
            cat "$FILE" >> $TMP_FILE
            mv $TMP_FILE "$FILE"
        fi
    else
        echo "$REQUIRED_LINE" >> "$FILE"
    fi
    chmod 644 "$FILE"
}

ensure_line_present \
    "^ *alaveteli *unix *.*" \
    "alaveteli unix  -       n       n       -       50      pipe flags=R user=$UNIX_USER argv=$REPOSITORY/script/mailin" \
    /etc/postfix/master.cf

ensure_line_present \
    "^ *virtual_alias_maps *= *regexp:/etc/postfix/regexp.*" \
    "virtual_alias_maps = regexp:/etc/postfix/regexp" \
    /etc/postfix/main.cf

ensure_line_present \
    "^.*alaveteli.*" \
    "/^foi.*/	alaveteli" \
    /etc/postfix/regexp

ensure_line_present \
    "^do-not-reply" \
    "do-not-reply-to-this-address:        :blackhole:" \
    /etc/aliases

ensure_line_present \
    "^mail.*" \
    "mail.*                          -/var/log/mail/mail.log" \
    /etc/rsyslog.d/50-default.conf

if ! egrep '^ */var/log/mail/mail.log *{' /etc/logrotate.d/rsyslog
then
    cat >> /etc/logrotate.d/rsyslog <<EOF
/var/log/mail/mail.log {
          rotate 30
          daily
          dateext
          missingok
          notifempty
          compress
          delaycompress
          sharedscripts
          postrotate
                  reload rsyslog >/dev/null 2>&1 || true
          endscript
}
EOF
fi

/etc/init.d/rsyslog restart

newaliases
postmap /etc/postfix/regexp
postfix reload

# (end of the Postfix configuration)

install_website_packages

# Make the PostgreSQL user a superuser to avoid the irritating error:
#   PG::Error: ERROR:  permission denied: "RI_ConstraintTrigger_16564" is a system trigger
add_postgresql_user --superuser

export DEVELOPMENT_INSTALL
su -c "$BIN_DIRECTORY/install-as-user '$UNIX_USER' '$HOST' '$DIRECTORY'" "$UNIX_USER"

if [ ! "$DEVELOPMENT_INSTALL" = true ]; then
    install_sysvinit_script
fi

# Set up root's crontab:

echo "The current directory is: $(pwd)"

sed -r \
    -e "s,^(MAILTO=).*,\1root@$HOST," \
    -e "s,\!\!\(\*= .user \*\)\!\!,$UNIX_USER,g" \
    -e "s,/data/vhost/\!\!\(\*= .vhost \*\)\!\!/\!\!\(\*= .vcspath \*\)\!\!,$REPOSITORY,g" \
    -e "s,/data/vhost/\!\!\(\*= .vhost \*\)\!\!,$DIRECTORY,g" \
    -e "s,run-with-lockfile,$REPOSITORY/commonlib/bin/run-with-lockfile.sh,g" \
    config/crontab-example > /etc/cron.d/alaveteli

sed -r \
    -e "s,\!\!\(\*= .user \*\)\!\!,$UNIX_USER,g" \
    -e "s,\!\!\(\*= .daemon_name \*\)\!\!,foi-alert-tracks,g" \
    -e "s,\!\!\(\*= .vhost_dir \*\)\!\!,$DIRECTORY,g" \
    config/alert-tracks-debian.ugly > /etc/init.d/foi-alert-tracks

sed -r \
    -e "s,\!\!\(\*= .user \*\)\!\!,$UNIX_USER,g" \
    -e "s,\!\!\(\*= .daemon_name \*\)\!\!,foi-alert-tracks,g" \
    -e "s,\!\!\(\*= .vhost_dir \*\)\!\!,$DIRECTORY,g" \
    config/purge-varnish-debian.ugly > /etc/init.d/foi-purge-varnish

chmod a+rx /etc/init.d/foi-alert-tracks
chmod a+rx /etc/init.d/foi-purge-varnish

done_msg "Installation complete"; echo
