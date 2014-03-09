#!/usr/bin/python2
#===============================================================================
#
#          FILE: PyPGW.py
#       LICENSE: GPLv3
#
#         USAGE: from PyPGW.PGW import Wallet
#                wallet = Wallet()
#                wallet.set_password("mail.google.com", "thomas", "789xyz")
#                wallet.get_password("mail.google.com", "thomas")
#                wallet.delete_password("mail.google.com", "thomas")
#
#   DESCRIPTION: Python 2.7 module for pgw integration
#
#       OPTIONS: supported(), get_password(), set_password(), delete_password()
#  REQUIREMENTS: Bash GnuPG and pgw with default fingerprint set
#          BUGS: No known bugs
#         NOTES: Best with "keychain" which maintains an unlocked gpg-agent
#        AUTHOR: Thomas Dwyer devel@tomd.tel
#  ORGANIZATION: http://tomd.tel/
#       CREATED: 01/22/2014 14:01 UTC
#       UPDATED: 02/07/2014 07:49 UTC
#      REVISION: v10.0
#===============================================================================
#
import subprocess

class Wallet:
  """
  Python Wrapper Class for pgw

  Usage:
  from PyPGW.PGW import Wallet
  wallet = Wallet()
  wallet.set_password("mail.google.com", "billy", "789xyz")
  wallet.get_password("mail.google.com", "billy")
  wallet.delete_password("mail.google.com", "billy")
  """

  def __init__(self, debug=False, service=None, username=None, password=None):
    self.debug = debug
    self.service = service
    self.username = username
    self.password = password
    self.supported()

  def supported(self):
    """If pgw is not installed
    OSError: [Errno 2] No such file or directory
    """
    args = ["pgw", "--help"]
    out = subprocess.check_output(args).strip()

  def get_password(self, service=None, username=None, default_value=None):
    """Get password of the username for the service
    """
    if service is None:
      service = self.service
    if username is None:
      username = self.username

    args = ["pgw", "-d", "-s", service, "-u", username]
    out = ""
    try:
      out = subprocess.check_output(args).strip()
    except subprocess.CalledProcessError:
      if not self.debug:
        out = default_value
    return out

  def set_password(self, service=None, username=None, password=None):
    """Set password for the username of the service
    """
    if service is None:
      service = self.service
    if username is None:
      username = self.username
    if password is None:
      password = self.password

    args = ["pgw", "-e", "-s", service, "-u", username, "-p", password]
    out = ''
    try:
      out = subprocess.check_output(args).strip()
    except subprocess.CalledProcessError:
      if self.debug: return out

#  vim: set ts=2 sw=2 tw=80 et :
