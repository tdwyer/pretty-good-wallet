gpg-wallet
==========

Think gnome-keyring but using gpg-agent instead of a dependency heavy, buggy daemon. Ideal in combination with Funtoo's 'keychian'

 - No Extra password to remember
 - No Extra service to fail
 - No Incompatible Database Files

  - 100% GnuPG
    - 4096 bit RSA Keys
    - 256 bit TwoFish

Mutt Config
-----------
I paid for this lavabit.com addres for 6 years.
I should at least be able to use it in examples.

<pre>
set my_pw_lavabit = `gpg-wallet lavabit.com tdwyer`
. . .
set imap_pass = $my_pw_lavabit
. . .
set smtp_pass = $my_pw_lavabit
. . .
account-hook $folder "set imap_user=$my_username imap_pass=$my_pw_lavabit"
</pre>

Python 2 Program Integration
----------------------------
Simply import.
Then set the passwords or get the passwords. Note that this will overwrite
stored passwords without warnning.

<pre>
import GpgWallet
wallet = GpgWallet.Wallet()

service = 'https://example.com/ampache/'
user = 'thomas'
password = 'pass_with_NO_spaces'

wallet.set_password('test', 'thomas', '123')
password = wallet.get_password('test', 'thomas')
</pre>

Lets see how it works...
------------------------
<pre>
_thomas_pts/7_walnut_
~% gpg-wallet --conf

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


_thomas_pts/7_walnut_
~% bash

[thomas@walnut ~]$ read -sp ' ?: ' pass
 ?: 
[thomas@walnut ~]$ gpg-wallet --batch lavabit.com tdwyer $pass
[thomas@walnut ~]$ exit
exit

_thomas_pts/7_walnut_
~% gpg-wallet lavabit.com tdwyer
MyPass

_thomas_pts/7_walnut_
~% gpg-wallet --new

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

_thomas_pts/7_walnut_
~% gpg-wallet lavabit.com tdwyer
NewPass

_thomas_pts/7_walnut_
~% ls -1R .gpg-wallet
.gpg-wallet:
B1BC2367EA1BA66E6A8C36F65B54EE7BF9BB32C81A5E0F9D39F5EB316B52D888
defaults.conf

.gpg-wallet/B1BC2367EA1BA66E6A8C36F65B54EE7BF9BB32C81A5E0F9D39F5EB316B52D888:
2A142C5942A0503BA015E78D24A9BA0EA2FC6E1956A62BECCE496F027B5C1FAD
E47A21F2604032D01B7D94470A58056900C7D8688DEF7AFAF1DC48775A4B89AF

_thomas_pts/7_walnut_
~%
</pre>
