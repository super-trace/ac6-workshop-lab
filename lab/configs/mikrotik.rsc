/user add name=oldprotocol password=newbrain group=full
/ip ssh set always-allow-password-login=yes
/file add name=ac6-workshop-key.pub contents="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILX/dcp2KWb01FKKtKR3V5MSFAURSWp8v1cf5UXCKYY+ ac6-workshop-lab"
:delay 2s
/user ssh-keys import public-key-file=ac6-workshop-key.pub user=oldprotocol
/file remove [find name=ac6-workshop-key.pub]
