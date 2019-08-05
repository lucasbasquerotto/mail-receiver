FROM ruby:2.3-alpine

RUN apk update \
	&& apk add postfix socat bash \
	&& rm -f /var/cache/apk/*

EXPOSE 25
VOLUME /var/spool/postfix

RUN >/etc/postfix/main.cf \
	&& postconf -e smtputf8_enable=no \
	&& postconf -e compatibility_level=2 \
	&& postconf -e export_environment='TZ LANG' \
	&& postconf -e smtpd_banner='ESMTP server' \
	&& postconf -e append_dot_mydomain=no \
	&& postconf -e mydestination=localhost \
	&& postconf -e alias_maps= \
	&& postconf -e mynetworks='127.0.0.0/8 [::1]/128 [fe80::]/64' \
	&& postconf -e transport_maps=hash:/etc/postfix/transport \
	&& postconf -e 'smtpd_recipient_restrictions = check_policy_service unix:private/policy' \
	&& postconf -M -e 'site/unix=site unix - n n - - pipe user=nobody:nogroup argv=/usr/local/bin/receive-mail ${recipient}' \
	&& postconf -M -e 'policy/unix=policy unix - n n - - spawn user=nobody argv=/usr/local/bin/site-smtp-fast-rejection' \
	&& rm -rf /var/spool/postfix/*

COPY receive-mail site-smtp-fast-rejection /usr/local/bin/
COPY lib/ /usr/local/lib/ruby/site_ruby/
COPY boot /sbin/

ADD https://github.com/mpalmer/socketee/releases/download/v0.0.2/socketee /usr/local/bin/
RUN chmod 0755 /usr/local/bin/socketee

CMD ["/sbin/boot"]
