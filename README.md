Virtual MFA
===========

Implementation of the [Time-Based One-Time Password Algorithm](http://tools.ietf.org/html/rfc6238) (TOTP) in Perl.  This script can be used as a virtual Multi-Factor Authentication (MFA) device for sites like [AWS](https://aws.amazon.com/iam/details/mfa/) and [GitHub](https://help.github.com/articles/about-two-factor-authentication/).

This utility can either be used as a primary virtual MFA device or a potential backup for smartphone apps like Google Authenticator.

Requirements
------------

  * Linux/Unix system with Perl installed
  * Perl *Digest::SHA* and *IO::Select* modules (typically part of core Perl).

Optional requirements, though highly recommended to avoid leaving your shared secrets out in the open, include [GnuPG](https://www.gnupg.org/) and a personal key pair.

Intended Usage
--------------

While you're welcome to edit `virtual-mfa.pl` and hard-code your MFA secret, storing the script _with secrets included_ in cleartext is a __bad idea__.  To avoid leaving your MFA shared secrets out in the open on your local filesystem, I ___strongly___ advise encrypting the script with something like `gpg`.

Included in this repository is a helper script (`generate_mfa.sh`) that can generate an encrypted version of `virtual-mfa.pl` containing your shared secret.  The resulting script can be executed like any other shell command, with the notable exception that you will need to provide your private key passphrase to decrypt the script logic and generate authentication codes.

For those who want to handle encryption/encoding/execution on their own, something like the following should suffice as an example (adjusting command paths accordingly):

```
cat <<\EOF > OUTPUT_FILENAME
#!/bin/sh
/usr/bin/gpg -d $0 | /usr/bin/perl
exit

\EOF

cat virtual-mfa.pl | \
  sed 's/DEPOSIT_SECRET_HERE/YOUR_SECRET/' | \
  gpg [--default-key KEY] --armor -ser RECIPIENT >> OUTPUT_FILENAME
chmod 700 OUTPUT_FILENAME
```

