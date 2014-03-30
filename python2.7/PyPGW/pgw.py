#!/usr/bin/python2
#===============================================================================
#
#          FILE: PyPGW.py
#       LICENSE: GPLv3
#
#         USAGE: Import pgw \n Interface = pgw.interface()
#
#   DESCRIPTION: Python 2.7 Pretty Good Wallet API
#
#       OPTIONS:
#  REQUIREMENTS:
#          BUGS:
#         NOTES:
#        AUTHOR: Thomas Dwyer devel@tomd.tel
#  ORGANIZATION: http://tomd.tel/
#      REVISION: v10.5
#===============================================================================
#
import subprocess

class Wallet(object):
  """The wallet object only contains metadata
  """
  def __init__(
      self,
      pgwKeyrings = dict,
      vaults = dict,
      ):
    self.pgwKeyrings = pgwKeyrings
    self.vaults = vaults

  def __str__(self):
    """For debuging in a Python shell
    """
    s = ""
    for pgwKeyring in self.pgwKeyrings.itervalues():
      s+="\nKeyring: " + pgwKeyring.domain
      for pgwKey in pgwKeyring.pgwKeys.itervalues():
        s+="\n    " + pgwKey.name
    for vault in self.vaults.itervalues():
      s+="\nVault: " + str(vault)
      for vfile in vault.vfiles.itervalues():
        s+="\n    " + str(vfile)
    return s

  def addObject(self, domain, obj_type, obj_name):
    """obj_meta takes domain str, obj_type str, obj_name str
    A PgwKeyring will be created if none in domain
    A Vault will be created if none in domain
    """
    if obj_type == 'keyring':
      self.addPgwKeyring(domain)
      self.pgwKeyrings[domain].addPgwKey(obj_name)

    elif obj_type == 'vault':
      self.addVault(domain)
      self.vaults[domain].addVFile(obj_name)

  def addPgwKeyring(self, pgwKeyring):
    """Accepts PgwKeyring object or PgwKeyring.domain str
    """
    if pgwKeyring.__class__ == PgwKeyring:
      if self.pgwKeyrings.has_key(pgwKeyring.domain):
        return "ERROR: Nameing conflict with PgwKeyring name " + pgwKeyring
      else:
        self.pgwKeyrings[pgwKeyring.domain] = pgwKeyring

    elif pgwKeyring.__class__ == str:
      domain = pgwKeyring
      if not self.pgwKeyrings.has_key(domain):
        self.pgwKeyrings[domain] = PgwKeyring(domain=domain, pgwKeys={})

  def addVault(self, vault):
    """Accepts Vault object or Vault.domain str
    """
    if vault.__class__ == Vault:
      if self.vaults.has_key(vault.domain):
        return "ERROR: Nameing conflict with Vault name " + vault
      else:
        self.vaults[vault.domain] = vault

    elif vault.__class__ == str:
      domain = vault
      if not self.vaults.has_key(domain):
        self.vaults[domain] = Vault(domain=domain, vfiles={})


class PgwKeyring(object):
  """Keyring object only contains metadata
  Interface.get_key(self.domain, self.keys[key])
  """
  def __init__(
      self,
      domain = str,
      pgwKeys = dict,
      ):
    self.domain = domain
    self.pgwKeys = pgwKeys

  def __str__(self):
    return self.domain

  def addPgwKey(self, pgwKey):
    """Acepts PgwKey object or PgwKey.name str
    """
    if pgwKey.__class__ == PgwKey:
      if self.pgwKeys.has_key(pgwKey.name):
        return "ERROR: Nameing conflict with Key name " + pgwKey.name
      else:
        self.pgwKeys[pgwKey.name] = pgwKey

    elif pgwKey.__class__ == str:
      name = pgwKey
      if not self.pgwKeys.has_key(name):
        self.pgwKeys[name] = PgwKey(name=name)

  def value(self, pgwKey):
    """Returns the value of a Key in the PGW Keyring
    """
    if pgwKey.__class__ == PgwKey:
      if not self.pgwKeys.has_key(pgwKey.name):
        return "ERROR: PGW Key: " + pgwKey.name + " is not in PgwKeyring"
      else:
        return self.pgwKeys[pgwKey.name].value(self.domain)

    elif pgwKey.__class__ == str:
      name = pgwKey
      if not self.pgwKeys.has_key(name):
        return "ERROR: PGW Key: " + name + " is not in PgwKeyring"
      else:
        return self.pgwKeys[name].value(self.domain)


class Vault(object):
  """The Vault object only contains metadata
  Interface.get_key(self.domain, self.vfiles[vfile])
  """
  def __init__(
      self,
      domain = str,
      vfiles = dict,
      ):
    self.domain = domain
    self.vfiles = vfiles

  def __str__(self):
    return self.domain

  def addVFile(self, vfile):
    """Acceptes VFile object or VFile.name str
    """
    if vfile.__class__ == VFile:
      if self.vfiles.has_key(vfile.name):
        return "ERROR: Nameing conflict with vfile " + vfile.name
      else:
        self.vfiles[vfile.name] = vfile

    elif vfile.__class__ == str:
      name = vfile
      if not self.vfiles.has_key(name):
        self.vfiles[name] = VFile(name=name)

  def value(self, vfile):
    """Returns the value of a file in the Vault()
    """
    if vfile.__class__ == VFile:
      if not self.vfiles.has_key(vfile.name):
        return "ERROR: vfile: " + vfile.name + " is not in Vault"
      else:
        return self.vfiles[vfile.name].value(self.domain)

    elif vfile.__class__ == str:
      name = vfile
      if not self.vfiles.has_key(name):
        return "ERROR: vfile: " + name + " is not in Vault"
      else:
        return self.vfiles[name].value(self.domain)

  def url(self):
    """If url file in Vault() return url
    """
    if self.vfiles.has_key("url"):
      return self.value("url")
    else:
      return ""

  def comment(self):
    """If url file in Vault() return url
    """
    if self.vfiles.has_key("comment"):
      return self.value("comment")
    else:
      return ""


class PgwKey(object):
  """Key object contains metadata, get value with PgwKeyring.value() function
  """

  def __init__(
      self,
      name = str,
      ):
    self.name = name

  def __str__(self):
    return self.name

  def value(self, domain):
    return Interface().get_pgwKeyValue(domain=domain, pgwKeyname=self.name)


class VFile(object):
  """ VFile object contains metadata, get value with Vault.value() function
  """

  def __init__(
      self,
      name = str,
      ):
    self.name = name

  def __str__(self):
    return self.name

  def value(self, domain):
    return Interface().get_VFileValue(domain=domain, vfilename=self.name)


class Interface(object):
  """
  Python Wrapper Class for pgw

  Usage:
  from PyPGW.pgw import Interface
  wallet = Interface()
  """

  def __init__(
      self,
      debug=False,
      default_value=None,
      ):
    self.debug = debug
    self.default_value = default_value
    self.supported()

  def setDebug(self, debug):
    self.debug = debug

  def setDefault_value(self, default_value):
    self.default_value = default_value

  def shell(self, args):
#    """Run a system command and handel errors
#    Takes list of strings as args
#    Returns raw output, empty string, or subprocess debug if debug=True
#    """
#    try:
#        out = subprocess.check_output(args).strip()
#    except subprocess.CalledProcessError:
#        if not self.debug: out = self.default_value
#    return out
    """Python dose not secure or wipe memory pages
    This probaly still leaks data...
    Hum maybe if I spesify a C_type class to store the data
    Then I could wipe the spesific memory pages... Right?
    """
    return subprocess.check_output(args).strip()

  def supported(self):
    """True if pgw and which are installed
    """
    out = self.shell(["which", "pgw"])
    if not out:
      return False
    else:
      return True

  def get_pgwKeyValue(
      self,
      domain=None,
      pgwKeyname=None,
      ):
    """Get password of the username for the domain
    """
    return self.shell(["pgw", "-stdout", "-d", domain, "-k", pgwKeyname])

  def set_pgwKeyValue(
      self,
      domain=None,
      keyname=None,
      keyvalue=None,
      ):
    """Set password for the username of the domain
    """
    return self.shell(["pgw", "-enc", "-d", domain, "-k", keyname, "-v", password])

  def get_VFileValue(
      self,
      domain=None,
      vfilename=None,
      ):
    """Get file from a domains vault
    """
    return self.shell(["pgw", "-stdout", "-d", domain, "-f", vfilename])

  def set_VFileValue(
      self,
      domain=None,
      filepath=None,
      ):
    """Takes domain of Vault() and the full path to file to put in the Vault()
    """
    return self.shell(["pgw", "-enc", "-d", domain, "-f", filepath])

  def populate_wallet(
      self,
      wallet=False,
      domain=False,
      obj_type=False,
      ):
    """Return Wallet() object containing imported metadata
    """
    if not wallet or wallet.__class__ != Wallet:
      wallet = Wallet(pgwKeyrings={}, vaults={})

    args = ["pgw", "-f"]
    if domain:
      args.append("-d")
      args.append(domain)

    if obj_type == "keyring":
      args.append("-k")

    elif obj_type == "vault":
      args.append("-f")

    a = self.shell(args).split('\n')[:-1]
    for item in a:
      b = item.split('/')[1:]
      _domain = b[0]
      _obj_type = b[1]

      if _obj_type == "keyring":
        _obj_name = b[2]

      elif _obj_type == "vault":
        _obj_name=""
        l = b[2].split('.')[:-1]
        while l:
          _obj_name+=l.pop(0)
          if l: _obj_name+="."

      wallet.addObject(_domain, _obj_type, _obj_name)

    return wallet

#  vim: set ts=2 sw=2 tw=80 et :
