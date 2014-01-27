#!/usr/bin/python2
#===============================================================================
#
#          FILE: gpg_wallet.py
#       LICENSE: GPGv3
#
#       INSTALL: install -Dm755 \
#                gpg-wallet/python2.7/keyring/backends/gpg_wallet.py \
#                /usr/lib/python2.7/site-packages/keyring/backends/gpg_wallet.py
#
#         USAGE: Python 2.7 keyring backend
#
#   DESCRIPTION: Python2-keyring backend support for gpg-wallet
#
#       OPTIONS: all requried
#  REQUIREMENTS: Bash GnuPG gpg-agent, python-2.7 & python2-keyring
#          BUGS: Prob.
#         NOTES: Best with "Funtoo keychain" which maintains unlocked gpg-agent
#        AUTHOR: Thomas Dwyer devel@tomd.tel
#  ORGANIZATION: http://tomd.tel/
#       CREATED: 01/05/2014 12:01 UTC
#       UPDATED: 01/05/2014 11:46 UTC
#      REVISION: 1.1
#===============================================================================
#
import subprocess
from keyring.backend import KeyringBackend
from keyring.errors import PasswordDeleteError
from keyring.errors import PasswordSetError, ExceptionRaisedContext

class Keyring(KeyringBackend):
    '''
    Interface with gpg-wallet a file-system based GPG encrypted password store
    '''
    def __init__(self):
        self.password = ''

    def supported(self):
        return 0

    def get_password(self, service, username):
        '''
        '''
        args = ["gpg-wallet", service, username]
        try:
            password = subprocess.check_output(args).strip()
        except subprocess.CalledProcessError:
            password = ''

        self.password = password
        return self.password

    def set_password(self, service, username, password):
        '''
        '''
        args = ["gpg-wallet", "--batch", service, username, password]
        try:
            out = subprocess.check_output(args).strip()
        except subprocess.CalledProcessError:
            raise PasswordSetError(out)
        
        self.password = password

        return 0

    def delete_password(self, service, username):
        '''
        '''
        args = ["gpg-wallet", "--rm", service, username]
        try:
            out = subprocess.check_output(args).strip()
        except subprocess.CalledProcessError:
            raise PasswordDeleteError(out)

        self.password = None

# vim: set ts=8 sw=4 tw=80 et :
