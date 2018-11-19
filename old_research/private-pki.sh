#!/bin/bash

# How to test

# bash -x private-pki.sh test01

test_name=$1
export root_ca_dir=$test_name/root-ca

export domain=things.com
company="Things"

conf_dir=private-pki/etc

# to struct root ca directory
mkdir -p $root_ca_dir/{certs,db,private,pp}
chmod 700 $root_ca_dir/private
touch $root_ca_dir/db/index
openssl rand -hex 16 > $root_ca_dir/db/serial
echo 1001 > $root_ca_dir/db/crlnumber

# to create a passphrase for the private key of root ca
openssl rand \
  -base64 48 \
  > $root_ca_dir/pp/ca_passphrase.txt

# to create root ca
openssl req \
  -new \
  -passout file:$root_ca_dir/pp/ca_passphrase.txt \
  -config $conf_dir/root-ca.conf \
  -out $root_ca_dir/root-ca.csr \
  -keyout $root_ca_dir/private/root-ca.key

openssl ca \
  -selfsign \
  -passin file:$root_ca_dir/pp/ca_passphrase.txt \
  -config $conf_dir/root-ca.conf \
  -in $root_ca_dir/root-ca.csr \
  -out $root_ca_dir/root-ca.crt \
  -extensions ca_ext \
  -batch

# to list the db file
cat $root_ca_dir/db/index

# to generate a crl for the new ca
openssl ca \
  -gencrl \
  -passin file:$root_ca_dir/pp/ca_passphrase.txt \
  -config $conf_dir/root-ca.conf \
  -out $root_ca_dir/root-ca.crl

cat $root_ca_dir/root-ca.crl

# to create a passphrase for the private key of ocsp
openssl rand \
  -base64 48 \
  > $root_ca_dir/pp/ocsp_passphrase.txt

openssl req \
  -new \
  -passout file:$root_ca_dir/pp/ocsp_passphrase.txt \
  -newkey rsa:2048 \
  -subj "/C=SE/O=Things/CN=OCSP Root Responder" \
  -keyout $root_ca_dir/private/root-ocsp-encrypted.key \
  -out $root_ca_dir/root-ocsp.csr

openssl rsa \
  -passin file:$root_ca_dir/pp/ocsp_passphrase.txt \
  -in $root_ca_dir/private/root-ocsp-encrypted.key \
  -out $root_ca_dir/private/root-ocsp.key

openssl ca \
  -passin file:$root_ca_dir/pp/ca_passphrase.txt \
  -config $conf_dir/root-ca.conf \
  -in $root_ca_dir/root-ocsp.csr \
  -out $root_ca_dir/root-ocsp.crt \
  -extensions ocsp_ext \
  -days 30 \
  -batch

sudo netstat -ntlp | \
  grep openssl | \
  awk '{print $7}' | \
  awk -F '/' '{print $1}' | \
  xargs kill

# for this, you have to enter passphrase manually
openssl ocsp \
 -port 9080 \
 -index $root_ca_dir/db/index \
 -rsigner $root_ca_dir/root-ocsp.crt \
 -rkey $root_ca_dir/private/root-ocsp.key \
 -CA $root_ca_dir/root-ca.crt \
 -text &

# to test ocsp responder remotely
openssl ocsp \
  -issuer $root_ca_dir/root-ca.crt \
  -CAfile $root_ca_dir/root-ca.crt \
  -cert $root_ca_dir/root-ocsp.crt \
  -url http://127.0.0.1:9080

#########################################################
#########################################################

export sub_ca_dir=$test_name/sub-ca

# to struct subodinate ca directory
mkdir -p $sub_ca_dir/{certs,db,private,pp}
chmod 700 $sub_ca_dir/private
touch $sub_ca_dir/db/index
openssl rand -hex 16 > $sub_ca_dir/db/serial
echo 1001 > $sub_ca_dir/db/crlnumber

# to create a passphrase for the private key of sub ca
openssl rand \
  -base64 48 \
  > $sub_ca_dir/pp/ca_passphrase.txt

# to create subordinate ca
openssl req \
  -new \
  -passout file:$sub_ca_dir/pp/ca_passphrase.txt \
  -config $conf_dir/sub-ca.conf \
  -out $sub_ca_dir/sub-ca.csr \
  -keyout $sub_ca_dir/private/sub-ca.key

openssl ca \
  -config $conf_dir/root-ca.conf \
  -passin file:$root_ca_dir/pp/ca_passphrase.txt \
  -in $sub_ca_dir/sub-ca.csr \
  -out $sub_ca_dir/sub-ca.crt \
  -batch \
  -extensions sub_ca_ext

# Subodinate ca operations
openssl rand \
  -base64 48 \
  > $sub_ca_dir/pp/server_passphrase.txt

# to create a CSR without prompt
cat << EOF > $conf_dir/$domain"_"$(date +%Y)_csr.cnf
[req]
distinguished_name  = dn
req_extensions      = ext
prompt              = no

[dn]
CN                  = *.$domain
emailAddress        = admin@$domain
O                   = $company
C                   = SE

[ext]
subjectAltName      = DNS:*.$domain,DNS:$domain
EOF

openssl req \
  -new \
  -passout file:$sub_ca_dir/pp/server_passphrase.txt \
  -keyout $sub_ca_dir/certs/$domain"_"$(date +%Y).key \
  -config $conf_dir/$domain"_"$(date +%Y)_csr.cnf \
  -out $sub_ca_dir/certs/$domain"_"$(date +%Y).csr

openssl ca \
  -config $conf_dir/sub-ca.conf \
  -batch \
  -passin file:$sub_ca_dir/pp/ca_passphrase.txt \
  -in $sub_ca_dir/certs/$domain"_"$(date +%Y).csr \
  -out $sub_ca_dir/certs/$domain"_"$(date +%Y).crt \
  -extensions server_ext

tree $1
