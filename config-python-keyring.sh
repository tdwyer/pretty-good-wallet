#!/bin/bash
#
# Thomas Dwyer <devel@tomd.tel>
# http://tomd.tel
# GPLv3
#
# Wacky, all of this should be done with| ./configure ; make ; make install
#

# Dose your distro default to Python3 or Python2 ?
PYTHON=/usr/bin/python
if [[ $(which python2 1>/dev/null 2>&1) ]] ;then
  PYTHON=$(which python2)
elif [[ $(which python3 1>/dev/null 2>&1) ]] ;then
  PYTHON=$(which python3)
  if [[ $(which GpgWallet.py 1>/dev/null 2>&1) ]] ;then
    for gw in $(find /usr/lib -name GpgWallet.py |grep -E 'keyring|gpgWallet')
    do
      sed 's/python2/python/' ${gw}
    done
  else
    echo "
    GpgWallet.py not found in /usr/lib
    You must change /usr/bin/python2 TO /usr/bin/python On First Line
    "
  fi
else
  echo "
    Python not found on system
  "
  exit 1
fi


# Configure Python2 keyring-3.3 config root location for your user
check="import keyring.util.platform_; print(keyring.util.platform_.data_root())"
#
[[ ! -d $(${PYTHON} -c "${check}") ]] && \
  mkdir -p $(${PYTHON} -c "${check}")

# Backup keyringrc.cfg if it exists
KEYRINGRC='keyringrc.cfg'
[[ -f "$(${PYTHON} -c "${check}")/${KEYRINGRC}" ]] &&
  mv "$(${PYTHON} -c "${check}")/${KEYRINGRC}" \
  "$(${PYTHON} -c "${check}")/${KEYRINGRC}-backup"

# Configure New keyring config for GpgWallet Backend
echo '[backend]
default-keyring=GpgWallet.Wallet
keyring-path=/usr/lib/python2.7/site-packages/keyring/backends
' > "$(${PYTHON} -c "${check}")/${KEYRINGRC}"

echo 'Python2 keyring-3.3 Configured for GpgWallet'

exit 0
