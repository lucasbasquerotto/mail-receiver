This container does the job of receiving an e-mail for a specified domain
and spawning an instance of another container to do "something" with the
e-mail.  That's it.  All very simple and straightforward.  You would
think...

Based on the discourse repository:

https://github.com/discourse/mail-receiver


# Installation and Configuration

Minimal configuration requires you to specify the domain you're receiving
mail for, and how to connect to your Site instance (URL, API key, etc).
This involves setting the following environment variables:

* `MAIL_DOMAIN` -- the domain name(s) to accept mail for and relay to
  the Site. Any number of space-separated domain names can be listed here.

* `SITE_BASE_URL` -- the base URL for this Site instance.
  This will be whatever your site URL is. For example,
  `https://subdomain.example.com`. If you're running a subfolder setup,
  be sure to account for that (ie `https://example.com/forum`).

* `SITE_API_KEY` -- the API key which will be used to authenticate to
  the site API in order to submit mail.

* `SITE_API_USERNAME` -- (optional) the user whose identity and
  permissions will be used to make requests to the site API.  This
  defaults to `system`.

* `SITE_API_HANDLE_MAIL_URL` -- the path relative to the site endpoint
  that will handle the http request that will send the email. E.g: 
  `admin/email/handle_mail`

* `SITE_API_SHOULD_REJECT_MAIL_URL` -- the path relative to the site endpoint
  that will return a JSON specifying if it should reject the email. E.g: 
  `admin/email/smtp_should_reject.json`  

For a straightforward setup, the above environment variables *should* be
enough to get you up and running.  If you have a desire for a more
complicated setup, the following subsections may provide you with the power
you need.


## Customised Postfix configuration

You can setup any Postfix configuration variables you need by setting env
vars of the form `POSTCONF_<var>` with the value of the variable you want.
For example, if you wanted to add a pre-delivery milter, you might use:

    -e POSTCONF_smtpd_milters=192.0.2.42:12345


## Blacklisting sender domains

The `BLACKLISTED_SENDER_DOMAINS` environment variable accepts a
space-separated list of domain names.  Mail messages from these senders will
be fast-failed with SMTP code 554.


## Syslog integration

Postfix loves to log everything to syslog.  In fact, that's really all it
supports.  Since, by default, Docker is not known for its superlative
out-of-the-box syslog integration, this container runs a tiny script which
reads all syslog data and dumps it to the container's `stderr` (which is
then examinable by `docker logs`).

If, by some chance, you want to process your Postfix logs more extensively,
you can set `SOCKETEE_RELAY_SOCKET` and all syslog messages will also be
sent to that socket for further processing.


# Theory of Operation

Every e-mail that is received is delivered to a custom `site` service.
That service, which is a small Ruby program, makes a POST request to the
admin interface on the specified URL (`SITE_BASE_URL`), with the key
and username specified. The site itself stands ready to receive that
e-mail and process it into the discussion, in exactly the same way as an
e-mail received via POP3 polling.

Before delivery to the `site` service, a Postfix policy handler runs,
asks the site if either the sender and/or recipient are invalid, and if so,
rejects the incoming mail during the SMTP transaction, to prevent the site
later sending out reply emails due to incoming spam ("backscatter").
Legitimate users will be notified of the failure by their MTA, and obvious
spam just gets dropped without reply. This step is just about being a good
citizen of the Internet and not full spam filtering.
