GpgWallet
==========
*A password manager you can work with*


**Support for Python Keyring** Working to replicate **Gnome-Keyring** and **KWallet** API's. The goal is to be supported by applications with no extra work from the application developers.
**Supports**
  - **gnu-screen**
    - Send password to Screens' Copy buffer
    - Send password to a gnu-screen windows' standard input
  - **Python Keyring**
    - Python2 keygring backend plugin
  - **Python 2.7**
    - Import gpgWallet for secure password storage and access in your Python programs
  - X11 Clipboard
    - Install `xclip` for copy to *clipbarod support*

**Features**
- It's file-system level
  - No Incompatible Database Files
  - Backup your passwords with _Git_
- 100% GnuPG
  - No Extra service to fail
  - Freedom to Choose and Change ciphers
    - 4096 bit RSA Keys or 1024 bit RSA Keys
    - 256 bit TwoFish or DES
  - No Extra password to remember, with gpg-agent
    - Best with `keyring` from the Funtoo Linux project which maintains an unlocked keychain
- Save files and notes with each service.


Mutt Config
-----------


    set my_pw_lavabit = $(gpgwallet lavabit.com tdwyer)
    set imap_pass = $my_pw_lavabit
    set smtp_pass = $my_pw_lavabit
    account-hook $folder "set imap_user=$my_username imap_pass=$my_pw_lavabit"


Python 2 Program Integration
----------------------------


Simply import. Then set the passwords or get the passwords. Note that this will overwrite stored passwords without warning.

    #!/usr/bin/python2
    from gpgWallet.GpgWallet import Wallet
    wallet = Wallet()
    service = 'https://example.com/ampache/'
    user = 'thomas'
    password = 'pass_with_NO_spaces'
    wallet.set_password(service, user, password)
    password = wallet.get_password(service, user)
    wallet.delete_password(service, user)


Bash Shell
----------


Save password for user account. From the shell you can save passwords with spaces in them.

    gpgwallet -e -s example.com -u alice
    Enter passwd:
    Re-enter passwd:

Save file for account

    gpgwallet -e -s example.com -f SecretQuestions.txt

Get decrypted file from encrypted storage

    gpgwallet -d -s example.com -f SecretQestions.txt >tmpfs/SecretQestions.txt

Copy password to X11 Clipboard

    gpgwallet -d --clip -s example.com -u alice

Copy password to Gnu Screen Copy / past buffer. *`env` $STY used as destination screen session*

    gpgwallet -d --screen -s example.com -u alice

Send password to a Gnu Screen Windows' stdin *`env` $STY used as destination screen session*

    gpgwallet -d --window 2 example.com -u alice


