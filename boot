#!/bin/bash

set -e

# Send syslog messages to stderr, optionally relaying them to another socket
# for postfix-exporter to take a look at
if [ -z "$SOCKETEE_RELAY_SOCKET" ]; then
	/usr/bin/socat UNIX-RECV:/dev/log,mode=0666 stderr &
else
	/usr/local/bin/socketee /dev/log "$SOCKETEE_RELAY_SOCKET" &
fi

echo "Operating environment:" >&2
env >&2

ruby -rjson -e "File.write('/etc/postfix/mail-receiver-environment.json', ENV.to_hash.to_json)"

if [ -z "$MAIL_DOMAIN" ]; then
	echo "FATAL ERROR: MAIL_DOMAIN env var is not set." >&2
	exit 1
fi

/usr/sbin/postconf -e relay_domains="$MAIL_DOMAIN"
rm -f /etc/postfix/transport
for d in $MAIL_DOMAIN; do
	echo "Delivering mail sent to $d to the endpoint" >&2
	/bin/echo "$d site:" >>/etc/postfix/transport
done
/usr/sbin/postmap /etc/postfix/transport

# Make sure the necessary site connection details are in place
for v in SITE_API_KEY SITE_API_USERNAME; do
	if [ -z "${!v}" ]; then
		echo "FATAL ERROR: $v env var is not set." >&2
		exit 1
	fi
done

if [ -z "$SITE_BASE_URL" ] && [ -z "$SITE_MAIL_ENDPOINT" ] ; then
	echo "FATAL ERROR: You need to define SITE_BASE_URL or SITE_MAIL_ENDPOINT" >&2
	exit 1
fi

# Generic postfix config setting code... bashers gonna bash.
for envvar in $(compgen -v); do
	if [[ "$envvar" =~ ^POSTCONF_ ]]; then
		varname="${envvar/POSTCONF_/}"
		echo "Setting $varname to '${!envvar}'" >&2
		/usr/sbin/postconf -e $varname="${!envvar}"
	fi
done

# Now, make sure that the Postfix filesystem environment is sane
mkdir -p -m 0755 /var/spool/postfix/pid
chown root:root /var/spool/postfix

/usr/sbin/postfix check >&2

if [ ! -z "$DEV" ] && [ "$DEV" = "1" ]; then
	echo "Starting Postfix (dev)" >&2

	while true; do 
		echo -e "request=smtpd_access_policy\nprotocol_state=RCPT\nsender=sender@from.com\nrecipient=recipient@to.com\n" \
			| /usr/local/bin/site-smtp-fast-rejection ||:
		sleep 5

		echo "email at $(date '+%F %X')" | /usr/local/bin/receive-mail 'test-recipient' ||:
		sleep 55
	done
else
	echo "Starting Postfix" >&2

	# Finally, let postfix-master do its thing
	exec /usr/lib/postfix/master -c /etc/postfix -d
fi