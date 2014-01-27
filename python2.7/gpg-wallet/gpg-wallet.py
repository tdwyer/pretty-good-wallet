#!/usr/bin/python2
#===============================================================================
#
#          FILE: GpgWallet.py
#       LICENSE: GPLv3
#
#         USAGE: Python 2 Wrapper for gpg-wallet
#
#   DESCRIPTION: For Encrypted password storage with Python 2.7 programs
#
#       OPTIONS: get_password(self, service, user, default_value=None)
#                set_password(self, service, user, password)
#  REQUIREMENTS: Bash GnuPG gpg-agent gpg-wallet
#          BUGS: None
#         NOTES: Best with "keychain" which maintains an unlocked gpg-agent
#        AUTHOR: Thomas Dwyer devel@tomd.tel
#  ORGANIZATION: http://tomd.tel/
#       CREATED: 01/22/2014 14:01 UTC
#       UPDATED: 01/23/2014 04:01 UTC
#      REVISION: 2.5
#===============================================================================
#
#from subprocess import call
import subprocess

class Wallet:
        """
        Python Wrapper Class for gpg-wallet

        Usage:
        import GpgWallet
        w = GpgWallet.Wallet()
        w.set_password('test', 'thomas', '123')
        w.get_password('test', 'thomas')
        """

        def __init__(self):
                service = ""
                user = ""

        def get_password(self, service, user, default_value=None):
                """
                Requires String as service value
                Requires String as user vlaue
                Optionaly Takes a default_value
                If no dafalut_value given it is set to None
                Return direct output from gpg-wallet, normally a password String
                Return default_value if no password in DB
                """
                args = ["gpg-wallet", service, user]
                try:
                        return subprocess.check_output(args).strip()
                except subprocess.CalledProcessError:
                        return default_value

        def set_password(self, service, user, password):
                """
                Requires String as service value
                Requires String as user value
                Returns nothing
                """
                args = ["gpg-wallet", "--batch", service, user, password, "force"]
                out = ''
                try:
                        out = subprocess.check_output(args)
                except subprocess.CalledProcessError:
                        out = out



#  vim: set ts=8 sw=8 tw=80 et :
