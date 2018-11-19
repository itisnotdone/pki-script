#!/bin/bash

# How to test
# rm -rf one.example.com; bash -x self-signed-ca.sh one example.com

domain=$2
sub_dc=$1

home=$1.$2
mkdir $home

company="Things Ltd"

# Key and Certificate Management
# to generate passphrase
if [ ! -f $home/passphrase.txt ]; then
  openssl rand \
    -base64 48 \
    > $home/passphrase.txt
fi

# to generate a rsa key using the passphrase
if [ ! -f $home/ca_private.key ]; then
  openssl genrsa \
    -aes128 \
    -passout file:$home/passphrase.txt \
    -out $home/ca_private.key 2048
fi

# to convert the key to a same key which does't have passphrase
# more convenient and available but less secure
if [ ! -f $home/ca_private_without_passphrase.key ]; then
openssl rsa \
  -passin file:$home/passphrase.txt \
  -in $home/ca_private.key \
  -out $home/ca_private_without_passphrase.key
fi

cp -v $home/ca_private_without_passphrase.key \
  $home/STAR.$sub_dc.$domain.key

# to check the structure of the key
# the private key itself has the key structure
openssl rsa \
  -text \
  -passin file:$home/passphrase.txt \
  -in $home/ca_private.key

# to extract public key
if [ ! -f $home/ca_public.key ]; then
  openssl rsa \
    -passin file:$home/passphrase.txt \
    -in $home/ca_private.key \
    -pubout \
    -out $home/ca_public.key
fi

cat $home/ca_public.key

# to create a CSR with prompt
# openssl req \
#   -new \
#   -key $home/ca_private_without_passphrase.key \
#   -out $home/"$domain"_"$(date +%Y)".csr

# to create a CSR from existing certificates
# openssl x509 \
#   -x509toreq \
#   -in $home/"$domain"_"$(date +%Y)".crt \
#   -out $home/"$domain"_"$(date +%Y)".csr \
#   -signkey $home/fd.key

if [ ! -f $home/$sub_dc."$domain"_$(date +%Y)_csr.cnf ]; then
# to create a CSR without prompt
cat << EOF > $home/$sub_dc."$domain"_$(date +%Y)_csr.cnf
[req]
prompt = no
distinguished_name = dn
req_extensions = ext

[dn]
CN = *.$sub_dc.$domain
emailAddress = admin@$sub_dc.$domain
O = $company
C = SE

[ext]
subjectAltName = DNS:*.$sub_dc.$domain,DNS:$sub_dc.$domain
EOF
fi

cat $home/$sub_dc."$domain"_$(date +%Y)_csr.cnf

if [ ! -f $home/$sub_dc."$domain"_$(date +%Y).csr ]; then
  openssl req \
    -new \
    -config $home/$sub_dc."$domain"_$(date +%Y)_csr.cnf \
    -key $home/ca_private_without_passphrase.key \
    -out $home/$sub_dc."$domain"_$(date +%Y).csr
fi

# to check the structure of the CSR
openssl req \
  -text \
  -in $home/$sub_dc."$domain"_$(date +%Y).csr \
  -noout

# to create a self-signed certificate
if [ ! -f $home/$sub_dc."$domain"_$(date +%Y).crt ]; then
openssl x509 \
  -req \
  -days 365 \
  -in $home/$sub_dc."$domain"_$(date +%Y).csr \
  -signkey $home/ca_private_without_passphrase.key \
  -out $home/$sub_dc."$domain"_$(date +%Y).crt
fi

# to create a CSR and CRT at the same time
# openssl req \
#   -new \
#   -x509 \
#   -days 365 \
#   -key $home/ca_private_without_passphrase.key \
#   -out $home/"$domain"_"$(date +%Y)".crt
#   -subj "/C=SE/O=$company/CN=*.$domain"

# to check the structure of the CRT
openssl x509 \
  -text \
  -in $home/$sub_dc."$domain"_$(date +%Y).crt \
  -noout

cp -v $home/$sub_dc."$domain"_$(date +%Y).crt \
  $home/STAR.$sub_dc.$domain.crt

tree $1.$2
