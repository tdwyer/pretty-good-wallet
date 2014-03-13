#!/usr/bin/python2
import os
import sys
import subprocess
from threading import Thread
from time import time, ctime, mktime
from kppy.database import *
from kppy.groups import *
from kppy.entries import *
from kppy.exceptions import *
from PyPGW.pgw import Wallet

class Pgw2Kdb():
    """Export pgw wallet to a Keepass v1 database
    """

    def __init__(self):
        args = ["pgw", "-s", "kdb", "-u", "filepath", "-d"]
        filepath = subprocess.check_output(args).strip()
        args = ["pgw", "-s", "kdb", "-u", "passphrase", "-d"]
        passphrase = subprocess.check_output(args).strip()
        self.kdb = KPDBv1(filepath, passphrase, new = True)
        self.pgw = Wallet()
        self.index = subprocess.check_output(["pgw", "-f", "-a"]).split('\n')[:-1]

    def genKdb(self):
        """
        """
        for item in index:
            account = item.split('/')[1:]
            title = account[0] + "_" + account[2]
            username = account[2]
            password = Wallet.get_password(



#  vim: set ts=4 sw=4 tw=80 et :
