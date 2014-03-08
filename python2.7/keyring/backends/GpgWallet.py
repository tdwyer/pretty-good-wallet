#!/usr/bin/python2
#===============================================================================
#
#          FILE: GpgWallet.py
#       LICENSE: GPLv3
#
#         USAGE: import keyring
#                keyring.set_keyring(GpgWallet.Wallet())
#
#   DESCRIPTION: Python 2 keyring-3.3 backend for gpgwallet
#
#       OPTIONS: supported(), get_password(), set_password(), delete_password()
#  REQUIREMENTS: Bash GnuPG and gpgwallet with default fingerprint set
#          BUGS: No known bugs
#         NOTES: Best with "keychain" which maintains an unlocked gpg-agent
#        AUTHOR: Thomas Dwyer devel@tomd.tel
#  ORGANIZATION: http://tomd.tel/
#       CREATED: 01/22/2014 14:01 UTC
#       UPDATED: 02/07/2014 07:49 UTC
#      REVISION: v10.0
#===============================================================================
#
from keyring.backend import KeyringBackend
from keyring.errors import PasswordDeleteError
from keyring.errors import PasswordSetError, ExceptionRaisedContext
import subprocess

class Wallet(KeyringBackend):
  """GpgWallet Backend"""

  def __init__(self, debug=False, service=None, username=None, password=None):
    self.service = service
    self.username = username
    self.password = password

  def supported(self):
    """If gpgwallet is installed return 0 else return -1
    """
    args = ["gpgwallet", "--help"]
    try:
      out = subprocess.check_output(args).strip()
      return 0
    except:
      return -1

  def get_password(self, service=None, username=None, default_value=None):
    """Get password of the username for the service
    """
    if service is None:
      service = self.service
    if username is None:
      username = self.username

    args = ["gpgwallet", "-d", "-s", service, "-u", username]
    out = ""
    try:
      out = subprocess.check_output(args).strip()
    except subprocess.CalledProcessError:
      if not self.debug:
        out = default_value
    return out

  def set_password(self, service=None, username=None, password=None):
    """Set password for the username of the service
    Unable to set a passwords with spaces
    """
    if service is None:
      service = self.service
    if username is None:
      username = self.username
    if password is None:
      password = self.password

    if ' ' in password:
      raise PasswordSetError("GpgWallet is unable save password with spaces in batch mode")
    args = ["gpgwallet", "-e", "-s", service, "-u", username, "-p", password]
    out = ''
    try:
      out = subprocess.check_output(args).strip()
    except subprocess.CalledProcessError:
      raise PasswordSetError(out)

  def delete_password(self, service=None, username=None):
    """Delete the password for the username of the service.
    """
    if service is None:
      service = self.service
    if username is None:
      username = self.username

#  vim: set ts=2 sw=2 tw=80 et :
