# pki-scripts

## Usage
Please make sure you run these commands at the root of this source repo.

```bash
bash -x main.sh quick_start

bash -x main.sh root_ca create
bash -x main.sh root_ca_ocsp issue

bash -x main.sh signing_ca create
bash -x main.sh signing_ca_ocsp issue

# to issue a site certificate
bash -x main.sh site issue

# to revoke a CA certificate signed by Root CA
bash -x main.sh revoke root_ca

# to revoke a site certificate signed by Signing CA
bash -x main.sh revoke signing_ca

# to generate CA-signed ssh key pairs
bash -x main.sh ssh_keypair issue USERNAME
bash -x main.sh ssh_keypair revoke USERNAME
```
