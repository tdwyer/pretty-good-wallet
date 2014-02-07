GpgWallet
==========
*A password manager you can work with*

**Support for Python Keyring** Working to replicate **Gnome-Keyring** and **KWallet** API's. The goal is to be supported by applications with no extra work from the application developers.

 - No Dependencies
 - No Extra password to remember
 - No Extra service to fail
 - No Incompatible Database Files
 - Know how your password are being encrypted
 - Have the Freedom to change Ciphers
 - It's file-system level
  - **Use _Git_ to backup your passwords**
 - It's Bash.., should run on anything

  - 100% GnuPG
    - 4096 bit RSA Keys
    - 256 bit TwoFish

Mutt Config
-----------

  set my_pw_lavabit = `gpgwallet lavabit.com tdwyer`
  . . .
  set imap_pass = $my_pw_lavabit
  . . .
  set smtp_pass = $my_pw_lavabit
  . . .
  account-hook $folder "set imap_user=$my_username imap_pass=$my_pw_lavabit"

Python 2 Program Integration
----------------------------
Simply import. Then set the passwords or get the passwords. Note that this will overwrite stored passwords without warnning.

  from gpgWallet.GpgWallet import Wallet
  wallet = Wallet()
  #
  service = 'https://example.com/ampache/'
  user = 'thomas'
  password = 'pass_with_NO_spaces'
  #
  wallet.set_password(service, user, password)
  password = wallet.get_password(service, user)
  wallet.delete_password(service, user)

Bash Shell
----------

### Set the Default GPG Fingerprint of the key to use
  gpgwallet --conf

    #####################################################################
    #                                                                   #
    #      Enter New FINGERPRINT or Leave Blank to Keep Current Key     #
    #       Default Key: D1B948F5D33BC668C3024D8760409BB9C18D3651       #
    #                                                                   #
    #####################################################################

    Enter New FINGERPRINT:

    #####################################################################
    #                                                                   #
    #               Set the Default GPG Key FINGERPRINT to              #
    #         GPG key: D1B948F5D33BC668C3024D8760409BB9C18D3651         #
    #                                                                   #
    #####################################################################

    (y/n/Q): y

### Save new account password in --batch mode *Good for scripting*
  read -s -p 'Type in the pass here so it is not saved in history: ' pass
  gpgwallet --batch 'mail.google.com' 'thomas' ${pass} force
*Without force gpgwallet will not overwrite*

### Lets get the password from Standard Out
  password = $(gpgwallet 'mail.google.com' 'thomas')
  echo $password

### Lets Delete the password
  gpgwallet --rm 'mail.google.com' 'thomas'

### This is what the GpgWallet *Wallet* looks like.
  ls -1R ~/.gpgwallet
    .gpgwallet:
    B1BC2367EA1BA66E6A8C36F65B54EE7BF9BB32C81A5E0F9D39F5EB316B52D888
    defaults.conf
    .gpgwallet/B1BC2367EA1BA66E6A8C36F65B54EE7BF9BB32C81A5E0F9D39F5EB316B52D888:
    2A142C5942A0503BA015E78D24A9BA0EA2FC6E1956A62BECCE496F027B5C1FAD
    E47A21F2604032D01B7D94470A58056900C7D8688DEF7AFAF1DC48775A4B89AF

### Lets check out the Interactive Mode

In Interactive mode has some over the top ASCI art :p
  gpgwallet --new

    #####################################################################
    #                                                                   #
    #   Enter Alternate Key Fingerprint or Leave Blank to use Default   #
    #       Default Key: D1B948F5D33BC668C3024D8760409BB9C18D3651       #
    #                                                                   #
    #####################################################################

    Alternate:

    #####################################################################
    #                                                                   #
    #                        Set Account Details                        #
    #                                                                   #
    #####################################################################

    Enter Service Name: lavabit.com
    Enter Username: tdwyer

    #####################################################################
    #                                                                   #
    #         Encrypt Account tdwyer@lavabit.com with GPG key
    #         GPG key: D1B948F5D33BC668C3024D8760409BB9C18D3651         #
    #                                                                   #
    #####################################################################

    (y/n): y

    #####################################################################
    #                                                                   #
    #                       Set Account Password                        #
    #              Sorry, No Spaces Allowed (Plese Fix Me)              #
    #                                                                   #
    #####################################################################

    Enter Password:
    Re-Enter Password:

    #####################################################################
    #                                                                   #
    #            The Username for this Service already exists           #
    #      This entry will have to be removed to save new password      #
    #                                                                   #
    #####################################################################

    Delete tdwyer@lavabit.com (y/n): y


