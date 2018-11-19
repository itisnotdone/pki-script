# pki-scripts

## Usage
Please make sure you run these commands at the root of this source repo.

```bash
bash -x pki.sh quick_start

bash -x pki.sh root_ca create
bash -x pki.sh root_ca_ocsp issue

bash -x pki.sh signing_ca create
bash -x pki.sh signing_ca_ocsp issue

bash -x pki.sh site issue

bash -x pki.sh revoke root_ca
bash -x pki.sh revoke signing_ca

# to generate CA-signed ssh key pairs
bash -x pki.sh ssh_keypair issue USERNAME
bash -x pki.sh ssh_keypair revoke USERNAME
```
