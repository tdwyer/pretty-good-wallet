#!/usr/bin/python2
#===============================================================================
#
#          FILE: pgw4keyring.py
#       LICENSE: GPLv3
#
#         USAGE: import keyring
#                keyring.set_keyring(pgw.Wallet())
#
#   DESCRIPTION: Python 2 keyring-3.3 backend for pgw
#
#       OPTIONS: supported(), get_password(), set_password(), delete_password()
#  REQUIREMENTS: Bash GnuPG and pgw with default fingerprint set
#          BUGS: No known bugs
#         NOTES: Best with "keychain" which maintains an unlocked gpg-agent
#        AUTHOR: Thomas Dwyer devel@tomd.tel
#  ORGANIZATION: http://tomd.tel/
#      REVISION: v10.4
#===============================================================================
#
from keyring.backend import KeyringBackend
from keyring.errors import PasswordDeleteError
from keyring.errors import PasswordSetError, ExceptionRaisedContext
import subprocess

class Wallet(KeyringBackend):
  """pgw Backend"""

  def __init__(self, debug=False, domain=None, pgwKey=None, password=None):
    self.domain = domain
    self.pgwKey = pgwKey
    self.password = password

  def supported(self):
    """If pgw is installed return 0 else return -1
    """
    args = ["pgw", "--help"]
    try:
      out = subprocess.check_output(args).strip()
      return 0
    except:
      return -1

  def shell(self, args):
    """Run system command in a subprocess and wait for it to finish
    """
    out = ""
    try:
      out = subprocess.check_output(args).strip()
    except subprocess.CalledProcessError:
      if not self.debug:
        out = default_value
    return out

  def get_password(self, domain=None, pgwKey=None, default_value=None):
    """Get password of the pgwKey of the domain
    """
    if domain is None:
      domain = self.domain
    if pgwKey is None:
      pgwKey = self.pgwKey

    return self.shell(["pgw", "-stdout", "-d", domain, "-k", pgwKey])

  def set_password(self, domain=None, pgwKey=None, password=None):
    """Set password for the pgwKey of the domain
    Unable to set a passwords with spaces
    """
    if domain is None:
      domain = self.domain
    if pgwKey is None:
      pgwKey = self.pgwKey
    if password is None:
      password = self.password

    if ' ' in password:
      raise PasswordSetError("pgw is unable save password with spaces in batch mode")
    args = ["pgw", "-e", "-d", domain, "-k", pgwKey, "-p", password]
    out = ''
    try:
      out = subprocess.check_output(args).strip()
    except subprocess.CalledProcessError:
      raise PasswordSetError(out)

#  vim: set ts=2 sw=2 tw=80 et :
