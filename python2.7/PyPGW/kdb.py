#!/usr/bin/python2
#===============================================================================
#
#          FILE: kdb.py
#       LICENSE: GPLv3
#
#         USAGE:
#
#   DESCRIPTION: Python 2.7 module for pgw kdb interaction
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
from PyPGW import pgw
# kppy.databases.create_group() returns the group instead of True
from PyPGW.kppy.database import *
from PyPGW.kppy.groups import *
from PyPGW.kppy.entries import *
from PyPGW.kppy.exceptions import *

class cmd():
    """Interface with Keepass v1 database files
    """

    def __init__(
            self,
            kdb_file = pgw.cmd().get_meta().vaults['kdb'].value('filepath'),
            kdb_password = pgw.cmd().get_meta().pgwKeyrings['kdb'].value('password'),
            new_kdb = True,
            ):
        self.kdb = KPDBv1(new = new_kdb)
        self.kdb.filepath = kdb_file
        self.kdb.password = kdb_password
        if not new_kdb:
            self.kdb.load()

    def pgw2kdb(self):
        """Export PGW Wallet to the KeePass v1 database
        database file is obained from wallet/kdb/vault/filepath
        database password is obained from wallet/kdb/keyring/kdb
        if exists, url is obtained from wallet/domain/vault/url
        if exists, comment is obtained from wallet/domain/vault/comment
        """
        wallet = pgw.cmd().get_meta()
        pgw_group = self.kdb.create_group(title="pgw")

        for pgwKeyring in wallet.pgwKeyrings.itervalues():
            domain = pgwKeyring.domain

            url = ""
            if wallet.vaults.has_key(domain):
                url = wallet.vaults[domain].url()

            comment = ""
            if wallet.vaults.has_key(domain):
                comment = wallet.vaults[domain].comment()

            for pgwKey in pgwKeyring.pgwKeys.itervalues():
                group = pgw_group
                title = domain + "_" + pgwKey.name
                username = pgwKey.name
                self.kdb.create_entry(
                        group = group,
                        title = title,
                        url = url,
                        username = username,
                        password = pgwKeyring.value(pgwKey),
                        comment = comment,
                        )

        self.kdb.save()
        self.kdb.close()

a = cmd()
a.pgw2kdb()
#  vim: set ts=4 sw=4 tw=80 et :
