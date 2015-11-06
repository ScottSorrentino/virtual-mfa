#!/bin/bash
#
# Simple script to automate creation of self-executing GPG scripts from
# virtual-mfa.pl.
#
# Scott Sorrentino <scott@sorrentino.net>
#
# Note that, if someone grabs a process list at the right moment, they may
# be able to catch your secret in our 'sed' call.
# 
# In my usual fashion, this is way more complicated than it needs to be ;)
#
# People who know what they are doing, and aren't worried about their shell
# command history exposing secrets, could just run something like:
#
#  cat <<\EOF > OUTPUT_FILENAME
#  #!/bin/sh
#  /usr/bin/gpg -d $0 | /usr/bin/perl
#  exit
#
#  \EOF
#
#  cat virtual-mfa.pl | \
#   sed 's/DEPOSIT_SECRET_HERE/YOUR_SECRET/' | \
#   gpg [--default-key KEY] --armor -ser RECIPIENT >> OUTPUT_FILENAME
#  chmod 700 OUTPUT_FILENAME
#

# Note that we're assuming 'cat', 'chmod', 'grep' and 'sed' all exist in
# the user's path...

ANS=""
CAT_CMD="cat"
CHMOD_CMD="chmod"
CMD_OUT=""
GPG_CMD=`which gpg`
GPG_RECIPIENT=""
GREP_CMD="grep"
PERL_CMD=`which perl`
SECRET_PLACEHOLDER="DEPOSIT_SECRET_HERE"
SECRET=""
SED_CMD="sed"
SOURCE_SCRIPT="./virtual-mfa.pl"
TARGET_FNAME=""

# Wrapper function for init_target(), catching errors and offering retries.
# Called during initial target script initialization *and* during retries
# caused by non-zero exit from encode_script().
function do_target_init() {
    init_target
    while [[ $? -ne 0 ]]; do
	echo ""
	echo -n "Error initializing ${TARGET_FNAME}.  Retry? "
	read ANS
	if [[ "${ANS}" == "y" ]] || [[ "${ANS}" == "Y" ]]; then
	    init_target
	else
	    echo "Aborting processing"
	    exit 1
	fi    
    done
}

# Encrypt source script after in-line replacement of secret placeholder,
# then include in target executable.
function encode_script() {
    ${CAT_CMD} ${SOURCE_SCRIPT}                         | \
	${SED_CMD} "s/${SECRET_PLACEHOLDER}/${SECRET}/" | \
	${GPG_CMD} --armor -ser ${GPG_RECIPIENT} >> ${TARGET_FNAME}
}

# Set up the target script as a shell executable.
function init_target() {
    echo "Initializing ${TARGET_FNAME}"
    cat <<EOF > ${TARGET_FNAME}
#!/bin/sh
${GPG_CMD} -d \$0 | ${PERL_CMD}
exit

EOF
    if [[ $? -eq 0 ]]; then
	${CHMOD_CMD} 700 ${TARGET_FNAME}
    fi
}

# Locate and perform basic usability test on system GnuPG executable.
function set_gpg() {
    if [[ ! -z "${GPG_CMD}" ]] && [[ -x "${GPG_CMD}" ]]; then
	${GPG_CMD} --version 2>&1 | ${GREP_CMD} -q "GnuPG"
    fi
    while [[ $? -ne 0 ]] || [[ -z "${GPG_CMD}" ]] || \
	[[ ! -x "${GPG_CMD}" ]]; do
	echo -n "Enter path to local GnuPG executable: "
	read GPG_CMD

	if [[ ! -z "${GPG_CMD}" ]] && [[ -x "${GPG_CMD}" ]]; then
	    ${GPG_CMD} --version 2>&1 | ${GREP_CMD} -q "GnuPG"
	fi
    done
}

# Obtain recipient for GnuPG encryption.
# Performs basic '--list-keys' test to see if recipient can be found by GnuPG.
function set_gpg_recipient() {
    if [[ ! -z "${GPG_RECIPIENT}" ]]; then
	${GPG_CMD} --list-keys ${GPG_RECIPIENT} 1>/dev/null 2>&1
    fi
    while [[ $? -ne 0 ]] || [[ -z "${GPG_RECIPIENT}" ]]; do
	[[ ! -z "${GPG_RECIPIENT}" ]] && \
	    echo "Did not find public key for recipient '${GPG_RECIPIENT}'."
	    
	echo -n "Enter recipient for encrypted script: "
	read GPG_RECIPIENT
	if [[ ! -z "${GPG_RECIPIENT}" ]]; then
	    ${GPG_CMD} --list-keys ${GPG_RECIPIENT} 1>/dev/null 2>&1
	fi
    done
}

# Locate and perform basic usability test on system Perl executable.
function set_perl() {
    if [[ ! -z "${PERL_CMD}" ]] && [[ -x "${PERL_CMD}" ]]; then
	CMD_OUT=`${PERL_CMD} -e 'print "Perl works"' 2>&1`
    fi
    while [[ -z "${PERL_CMD}" ]] || [[ ! -x "${PERL_CMD}" ]] || \
	[[ "${CMD_OUT}" != "Perl works" ]]; do
	if [[ ! -z "${PERL_CMD}" ]] && [[ -x "${PERL_CMD}" ]] && \
	    [[ ! -z "${CMD_OUT}" ]]; then
	    echo ${CMD_OUT}
	fi
	echo -n "Enter path to local Perl executable: "
	read PERL_CMD

	if [[ ! -z "${PERL_CMD}" ]] && [[ -x "${PERL_CMD}" ]]; then
	    CMD_OUT=`${PERL_CMD} -e 'print "Perl works"' 2>&1`
	fi
    done
}

# Define the secret used to initialize the MFA token
function set_secret() {
    while [[ -z "${SECRET}" ]]; do
	echo -n "Enter the MFA secret to store: "
	read SECRET
    done
}

# Locate and perform basic usability test on virtual-mfa source script.
function set_source() {
    if [[ ! -z "${SOURCE_SCRIPT}" ]] && [[ -r "${SOURCE_SCRIPT}" ]]; then
	${GREP_CMD} -q "${SECRET_PLACEHOLDER}" ${SOURCE_SCRIPT}
    fi
    while [[ $? -ne 0 ]] || [[ -z "${SOURCE_SCRIPT}" ]] || \
	[[ ! -r "${SOURCE_SCRIPT}" ]]; do
	[[ ! -z "${SOURCE_SCRIPT}" ]] && \
	    echo "Unable to read or find ${SECRET_PLACEHOLDER} in ${SOURCE_SCRIPT}."
	    
	echo -n "Enter local path to virtual-mfa script: "
	read SOURCE_SCRIPT
	if [[ ! -z "${SOURCE_SCRIPT}" ]] && [[ -r "${SOURCE_SCRIPT}" ]]; then
	    ${GREP_CMD} -q "${SECRET_PLACEHOLDER}" ${SOURCE_SCRIPT}
	fi
    done
}

# Define output target for encrypted, self-executable script.
function set_target() {
    while [[ -z "${TARGET_FNAME}" ]] || [[ -e "${TARGET_FNAME}" ]]; do
	echo -n "Enter destination path for encrypted virtual-mfa script: "
	read TARGET_FNAME
	if [[ ! -z "${TARGET_FNAME}" ]] && [[ -e "${TARGET_FNAME}" ]]; then
	    echo -n "File ${TARGET_FNAME} already exists.  Replace? "
	    read ANS
	    if [[ "${ANS}" == "y" ]] || [[ "${ANS}" == "Y" ]]; then
		rm -f ${TARGET_FNAME}
	    fi
	fi
    done
}


# Can we locate the source script (ie: lives where we expect)?
set_source
echo "Using ${SOURCE_SCRIPT} as basis for encrypted version."

# Set perl executable
set_perl
echo "Using ${PERL_CMD} as Perl executable."

# Basic check that we have a workable GPG executable
set_gpg
echo "Using GnuPG executable ${GPG_CMD}."

# Set recipient for encrypted script
set_gpg_recipient
echo "Using GnuPG recipient '${GPG_RECIPIENT}':"
${GPG_CMD} --list-keys ${GPG_RECIPIENT}

# Set output location
set_target
echo "Using ${TARGET_FNAME} as encrypted script."

# Obtain secret
set_secret

# Would be nice to use 'mktemp' here instead of directly writing to target.
do_target_init

# Append GPG-encrypted data
echo "Encoding ${SOURCE_SCRIPT} into ${TARGET_FNAME}."
echo "You will likely be prompted by GPG for your signing key passphrase."
encode_script
while [[ $? -ne 0 ]]; do
    echo ""
    echo -n "Error encoding ${SOURCE_SCRIPT} into ${TARGET_FNAME}.  Retry? "    read ANS
    if [[ "${ANS}" == "y" ]] || [[ "${ANS}" == "Y" ]]; then
	do_target_init
	encode_script
    else
	echo "Aborting processing"
	exit 1
    fi    
done

echo "All set.  Executable script stored as: ${TARGET_FNAME}"
echo "Run the executable to generate MFA codes."
