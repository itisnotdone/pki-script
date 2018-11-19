#!/bin/bash

export home=$1  # This has to be a relative path from where you are
home=${home:-result_expert}

if [ ! -d expert-pki ]; then
  git clone https://github.com/itisnotdone/expert-pki.git
  # replace dir variable from '.' to '$ENV::home' for all conf files
fi

echo -e "\n\n##################  1. Create Root CA"
echo -e "\n\n##################  1.1 Create directories"
mkdir -pv $home/ca/root-ca/{private,db} $home/{crl,certs,pp}
ln -sv $PWD/expert-pki/etc $PWD/$home/etc
chmod 700 $home/ca/root-ca/private

echo -e "\n\n##################  1.2 Create database"
cp -v /dev/null $home/ca/root-ca/db/root-ca.db
cp -v /dev/null $home/ca/root-ca/db/root-ca.db.attr
echo 01 | tee $home/ca/root-ca/db/root-ca.crt.srl
echo 01 | tee $home/ca/root-ca/db/root-ca.crl.srl

echo -e "\n\n##################  Generate passphrase for root ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/root-ca-passphrase.txt

echo -e "\n\n##################  1.3 Create root CSR"
openssl req -new \
  -passout file:$home/pp/root-ca-passphrase.txt \
  -config $home/etc/root-ca.conf \
  -out $home/ca/root-ca.csr \
  -keyout $home/ca/root-ca/private/root-ca.key

echo -e "\n\n##################  1.3.1 Print root CA private key"
openssl rsa \
  -text \
  -passin file:$home/pp/root-ca-passphrase.txt \
  -in $home/ca/root-ca/private/root-ca.key

echo -e "\n\n##################  1.3.2 Print root CA CSR"
openssl req \
  -text \
  -in $home/ca/root-ca.csr \
  -noout

echo -e "\n\n##################  1.4 Create Root CA certificate"
openssl ca -selfsign \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -batch \
  -config $home/etc/root-ca.conf \
  -in $home/ca/root-ca.csr \
  -out $home/ca/root-ca.crt \
  -extensions root_ca_ext \
  -enddate 20301231235959Z
# 2048-bit RSA keys are deemed safe until 2030.

echo -e "\n\n##################  1.4.1 Print root CA certificate"
openssl x509 -text \
  -in $home/ca/root-ca.crt

echo -e "\n\n##################  1.5 Create initial CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -config $home/etc/root-ca.conf \
  -out $home/crl/root-ca.crl

echo -e "\n\n##################  1.5.1 Print Root CA CRL"
openssl crl \
  -text \
  -noout \
  -in $home/crl/root-ca.crl

echo -e "\n\n##################  2. Create Network CA"
echo -e "\n\n##################  2.1 Create directories"
mkdir -pv $home/ca/network-ca/{private,db}
chmod 700 $home/ca/network-ca/private

echo -e "\n\n##################  2.2 Create database"
cp -v /dev/null $home/ca/network-ca/db/network-ca.db
cp -v /dev/null $home/ca/network-ca/db/network-ca.db.attr
echo 01 | tee $home/ca/network-ca/db/network-ca.crt.srl
echo 01 | tee $home/ca/network-ca/db/network-ca.crl.srl

echo -e "\n\n##################  Generate passphrase for network ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/network-ca-passphrase.txt

echo -e "\n\n##################  2.3 Create CSR"
openssl req -new \
  -passout file:$home/pp/network-ca-passphrase.txt \
  -config $home/etc/network-ca.conf \
  -out $home/ca/network-ca.csr \
  -keyout $home/ca/network-ca/private/network-ca.key

echo -e "\n\n##################  2.3.1 Print network CA private key"
openssl rsa \
  -text \
  -passin file:$home/pp/network-ca-passphrase.txt \
  -in $home/ca/network-ca/private/network-ca.key

echo -e "\n\n##################  2.3.2 Print network CA CSR"
openssl req \
  -text \
  -in $home/ca/network-ca.csr \
  -noout

echo -e "\n\n##################  2.4 Create Network CA certificate"
openssl ca \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -batch \
  -config $home/etc/root-ca.conf \
  -in $home/ca/network-ca.csr \
  -out $home/ca/network-ca.crt \
  -extensions intermediate_ca_ext \
  -enddate 20301231235959Z
# Intermediate CAs should have the same life span as their root CAs.

echo -e "\n\n##################  2.4.1 Print network CA certificate"
openssl x509 -text \
  -in $home/ca/network-ca.crt

echo -e "\n\n##################  2.5 Create initial CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/network-ca-passphrase.txt \
  -config $home/etc/network-ca.conf \
  -out $home/crl/network-ca.crl

echo -e "\n\n##################  2.5.1 Print Network CA CRL"
openssl crl \
  -text \
  -noout \
  -in $home/crl/network-ca.crl

echo -e "\n\n##################  2.6 Create PEM bundle"
cat $home/ca/network-ca.crt $home/ca/root-ca.crt | tee \
  $home/ca/network-ca-chain.pem

echo -e "\n\n##################  3. Create Identity CA"
echo -e "\n\n##################  3.1 Create directories"
mkdir -pv $home/ca/identity-ca/{private,db}
chmod 700 $home/ca/identity-ca/private

echo -e "\n\n##################  3.2 Create database"
cp -v /dev/null $home/ca/identity-ca/db/identity-ca.db
cp -v /dev/null $home/ca/identity-ca/db/identity-ca.db.attr
echo 01 | tee $home/ca/identity-ca/db/identity-ca.crt.srl
echo 01 | tee $home/ca/identity-ca/db/identity-ca.crl.srl

echo -e "\n\n##################  Generate passphrase for identity ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/identity-ca-passphrase.txt

echo -e "\n\n##################  3.3 Create CSR"
openssl req -new \
  -passout file:$home/pp/identity-ca-passphrase.txt \
  -config $home/etc/identity-ca.conf \
  -out $home/ca/identity-ca.csr \
  -keyout $home/ca/identity-ca/private/identity-ca.key

echo -e "\n\n##################  3.3.1 Print Identity CA private key"
openssl rsa \
  -text \
  -passin file:$home/pp/identity-ca-passphrase.txt \
  -in $home/ca/identity-ca/private/identity-ca.key

echo -e "\n\n##################  3.3.2 Print Identity CA CSR"
openssl req \
  -text \
  -in $home/ca/identity-ca.csr \
  -noout

echo -e "\n\n##################  3.4 Create Identity CA certificate"
openssl ca \
  -passin file:"$home"/pp/network-ca-passphrase.txt \
  -batch \
  -config $home/etc/network-ca.conf \
  -in $home/ca/identity-ca.csr \
  -out $home/ca/identity-ca.crt \
  -extensions signing_ca_ext

echo -e "\n\n##################  3.4.1 Print Identity CA certificate"
openssl x509 -text \
  -in $home/ca/identity-ca.crt

echo -e "\n\n##################  3.5 Create initial CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/identity-ca-passphrase.txt \
  -config $home/etc/identity-ca.conf \
  -out $home/crl/identity-ca.crl

echo -e "\n\n##################  3.5.1 Print Identity CA CRL"
openssl crl \
  -text \
  -noout \
  -in $home/crl/identity-ca.crl

echo -e "\n\n##################  3.6 Create PEM bundle"
cat $home/ca/identity-ca.crt $home/ca/network-ca-chain.pem | tee \
  $home/ca/identity-ca-chain.pem

echo -e "\n\n##################  4. Create Component CA"
echo -e "\n\n##################  4.1 Create directories"
mkdir -pv $home/ca/component-ca/{private,db}
chmod 700 $home/ca/component-ca/private

echo -e "\n\n##################  4.2 Create database"
cp -v /dev/null $home/ca/component-ca/db/component-ca.db
cp -v /dev/null $home/ca/component-ca/db/component-ca.db.attr
echo 01 | tee $home/ca/component-ca/db/component-ca.crt.srl
echo 01 | tee $home/ca/component-ca/db/component-ca.crl.srl

echo -e "\n\n##################  Generate passphrase for component ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/component-ca-passphrase.txt

echo -e "\n\n##################  4.3 Create CSR"
openssl req -new \
  -passout file:$home/pp/component-ca-passphrase.txt \
  -config $home/etc/component-ca.conf \
  -out $home/ca/component-ca.csr \
  -keyout $home/ca/component-ca/private/component-ca.key

echo -e "\n\n##################  4.3.1 Print Component CA private key"
openssl rsa \
  -text \
  -passin file:$home/pp/component-ca-passphrase.txt \
  -in $home/ca/component-ca/private/component-ca.key

echo -e "\n\n##################  4.3.2 Print Component CA CSR"
openssl req \
  -text \
  -in $home/ca/component-ca.csr \
  -noout

echo -e "\n\n##################  4.4 Create Component CA certificate"
openssl ca \
  -passin file:"$home"/pp/network-ca-passphrase.txt \
  -batch \
  -config $home/etc/network-ca.conf \
  -in $home/ca/component-ca.csr \
  -out $home/ca/component-ca.crt \
  -extensions signing_ca_ext

echo -e "\n\n##################  4.4.1 Print Component CA certificate"
openssl x509 -text \
  -in $home/ca/component-ca.crt

echo -e "\n\n##################  4.5 Create initial CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/component-ca-passphrase.txt \
  -config $home/etc/component-ca.conf \
  -out $home/crl/component-ca.crl

echo -e "\n\n##################  4.5.1 Print Component CA CRL"
openssl crl \
  -text \
  -noout \
  -in $home/crl/component-ca.crl

echo -e "\n\n##################  4.6 Create PEM bundle"
cat $home/ca/component-ca.crt $home/ca/network-ca-chain.pem | tee \
  $home/ca/component-ca-chain.pem

echo -e "\n\n##################  5. Operate Identity CA"

echo -e "\n\n##################  Generate passphrase for fred"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/fred-id-passphrase.txt

echo -e "\n\n##################  5.1 Create identity request"
openssl req -new \
  -passout file:$home/pp/fred-id-passphrase.txt \
  -config $home/etc/identity.conf \
  -out $home/certs/fred-id.csr \
  -keyout $home/certs/fred-id.key
# DN: C=SE, O=Blue AB, CN=Fred Flintstone, emailAddress=fred@blue.se

echo -e "\n\n##################  5.1.1 Print Fred private key"
openssl rsa \
  -text \
  -passin file:$home/pp/fred-id-passphrase.txt \
  -in $home/certs/fred-id.key

echo -e "\n\n##################  5.1.2 Print Fred CSR"
openssl req \
  -text \
  -in $home/certs/fred-id.csr \
  -noout

echo -e "\n\n##################  5.2 Create Fred identity certificate"
openssl ca \
  -passin file:"$home"/pp/identity-ca-passphrase.txt \
  -batch \
  -config $home/etc/identity-ca.conf \
  -in $home/certs/fred-id.csr \
  -out $home/certs/fred-id.crt \
  -extensions identity_ext

echo -e "\n\n##################  5.2.1 Print Fred CA certificate"
openssl x509 -text \
  -in $home/certs/fred-id.crt

echo -e "\n\n##################  5.3 Create PKCS#12 bundle"
openssl pkcs12 -export \
  -passin file:"$home"/pp/fred-id-passphrase.txt \
  -password pass:blahblah \
  -name "Fred Flintstone (Blue Identity)" \
  -caname "Blue Identity CA" \
  -caname "Blue Network CA" \
  -caname "Blue Root CA" \
  -inkey $home/certs/fred-id.key \
  -in $home/certs/fred-id.crt \
  -certfile $home/ca/identity-ca-chain.pem \
  -out $home/certs/fred-id.p12

echo -e "\n\n##################  5.4 Create encryption request"
openssl req -new \
  -passout file:$home/pp/fred-id-passphrase.txt \
  -config $home/etc/encryption.conf \
  -out $home/certs/fred-enc.csr \
  -keyout $home/certs/fred-enc.key
# DN: C=SE, O=Blue AB, CN=Fred Flintstone, emailAddress=fred@blue.se

echo -e "\n\n##################  5.5 Create Fred encryption certificate"
openssl ca \
  -passin file:"$home"/pp/identity-ca-passphrase.txt \
  -batch \
  -config $home/etc/identity-ca.conf \
  -in $home/certs/fred-enc.csr \
  -out $home/certs/fred-enc.crt \
  -extensions encryption_ext

echo -e "\n\n##################  5.5.1 Print Fred CA certificate"
openssl x509 -text \
  -in $home/certs/fred-enc.crt

echo -e "\n\n##################  5.6 Create PKCS#12 bundle"
openssl pkcs12 -export \
  -passin file:"$home"/pp/fred-id-passphrase.txt \
  -password pass:blahblah \
  -name "Fred Flintstone (Blue Encryption)" \
  -caname "Blue Identity CA" \
  -caname "Blue Network CA" \
  -caname "Blue Root CA" \
  -inkey $home/certs/fred-enc.key \
  -in $home/certs/fred-enc.crt \
  -certfile $home/ca/identity-ca-chain.pem \
  -out $home/certs/fred-enc.p12

echo -e "\n\n##################  5.7 Revoke certificate"
openssl ca \
  -passin file:"$home"/pp/identity-ca-passphrase.txt \
  -config $home/etc/identity-ca.conf \
  -revoke $home/ca/identity-ca/02.pem \
  -crl_reason superseded

echo -e "\n\n##################  5.8 Create CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/identity-ca-passphrase.txt \
  -config $home/etc/identity-ca.conf \
  -out $home/crl/identity-ca.crl

echo -e "\n\n##################  5.8.1 Print Identity CA CRL"
openssl crl \
  -text \
  -noout \
  -in $home/crl/identity-ca.crl

echo -e "\n\n##################  6. Operate Component CA"

echo -e "\n\n##################  Generate passphrase for TLS server"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/server-passphrase.txt

echo -e "\n\n##################  6.1 Create TLS server request"
SAN=DNS:blue.se,DNS:www.blue.se \
openssl req -new \
  -passout file:$home/pp/server-passphrase.txt \
  -config $home/etc/server.conf \
  -out $home/certs/blue.se.csr \
  -keyout $home/certs/blue.se.key
# DN: C=SE, O=Blue AB, CN=www.blue.se

echo -e "\n\n##################  6.1.1 Print server private key"
openssl rsa \
  -text \
  -passin file:$home/pp/server-passphrase.txt \
  -in $home/certs/blue.se.key

echo -e "\n\n##################  6.1.2 Print server CSR"
openssl req \
  -text \
  -in $home/certs/blue.se.csr \
  -noout

echo -e "\n\n##################  6.2 Create TLS server certificate"
openssl ca \
  -passin file:"$home"/pp/component-ca-passphrase.txt \
  -batch \
  -config $home/etc/component-ca.conf \
  -in $home/certs/blue.se.csr \
  -out $home/certs/blue.se.crt \
  -extensions server_ext

echo -e "\n\n##################  6.2.1 Print TLS server certificate"
openssl x509 -text \
  -in $home/certs/blue.se.crt

echo -e "\n\n##################  Generate passphrase for TLS client"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/tls-client-passphrase.txt

echo -e "\n\n##################  6.3 Create TLS client request"
openssl req -new \
  -passout file:$home/pp/tls-client-passphrase.txt \
  -config $home/etc/client.conf \
  -out $home/certs/net-mon.csr \
  -keyout $home/certs/net-mon.key
# DN: C=SE, O=Blue AB, CN=Blue Network Monitoring

echo -e "\n\n##################  6.3.1 Print server private key"
openssl rsa \
  -text \
  -passin file:$home/pp/tls-client-passphrase.txt \
  -in $home/certs/net-mon.key

echo -e "\n\n##################  6.3.2 Print server CSR"
openssl req \
  -text \
  -in $home/certs/net-mon.csr \
  -noout

echo -e "\n\n##################  6.4 Create TLS client certificate"
openssl ca \
  -passin file:"$home"/pp/component-ca-passphrase.txt \
  -batch \
  -config $home/etc/component-ca.conf \
  -in $home/certs/net-mon.csr \
  -out $home/certs/net-mon.crt \
  -extensions client_ext

echo -e "\n\n##################  6.4.1 Print TLS client certificate"
openssl x509 -text \
  -in $home/certs/net-mon.crt

echo -e "\n\n##################  Generate passphrase for time-stamping private key"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/tsa-passphrase.txt

echo -e "\n\n##################  6.5 Create time-stamping request"
openssl req -new \
  -passout file:$home/pp/tsa-passphrase.txt \
  -config $home/etc/timestamp.conf \
  -out $home/certs/tsa.csr \
  -keyout $home/certs/tsa.key
# DN: C=SE, O=Blue AB, OU=Blue TSA, CN=Blue TSA

echo -e "\n\n##################  6.5.1 Print time-stamping private key"
openssl rsa \
  -text \
  -passin file:$home/pp/tsa-passphrase.txt \
  -in $home/certs/tsa.key

echo -e "\n\n##################  6.5.2 Print time-stamping CSR"
openssl req \
  -text \
  -in $home/certs/tsa.csr \
  -noout

echo -e "\n\n##################  6.6 Create time-stamping certificate"
openssl ca \
  -passin file:"$home"/pp/component-ca-passphrase.txt \
  -batch \
  -config $home/etc/component-ca.conf \
  -in $home/certs/tsa.csr \
  -out $home/certs/tsa.crt \
  -extensions timestamp_ext \
  -days 1826

echo -e "\n\n##################  6.6.1 Print time-stamping certificate"
openssl x509 -text \
  -in $home/certs/tsa.crt

echo -e "\n\n##################  Generate passphrase for OCSP-signing private key"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/ocsp-passphrase.txt

echo -e "\n\n##################  6.7 Create OCSP-signing request"
openssl req -new \
  -passout file:$home/pp/ocsp-passphrase.txt \
  -config $home/etc/ocspsign.conf \
  -out $home/certs/ocsp.csr \
  -keyout $home/certs/ocsp.key
# DN: C=SE, O=Blue AB, CN=Blue OCSP Responder

echo -e "\n\n##################  6.7.1 Print OCSP-signing private key"
openssl rsa \
  -text \
  -passin file:$home/pp/ocsp-passphrase.txt \
  -in $home/certs/ocsp.key

echo -e "\n\n##################  6.7.2 Print OCSP-signing CSR"
openssl req \
  -text \
  -in $home/certs/ocsp.csr \
  -noout

echo -e "\n\n##################  6.8 Create OCSP-signing certificate"
openssl ca \
  -passin file:"$home"/pp/component-ca-passphrase.txt \
  -batch \
  -config $home/etc/component-ca.conf \
  -in $home/certs/ocsp.csr \
  -out $home/certs/ocsp.crt \
  -extensions ocspsign_ext \
  -days 14

echo -e "\n\n##################  6.8.1 Print ocsp certificate"
openssl x509 -text \
  -in $home/certs/ocsp.crt

echo -e "\n\n##################  6.9 Revoke certificate"
openssl ca \
  -passin file:"$home"/pp/component-ca-passphrase.txt \
  -config $home/etc/component-ca.conf \
  -revoke $home/ca/component-ca/02.pem \
  -crl_reason superseded

echo -e "\n\n##################  6.10 Create CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/component-ca-passphrase.txt \
  -config $home/etc/component-ca.conf \
  -out $home/crl/component-ca.crl

echo -e "\n\n##################  6.10.1 Print Component CA CRL"
openssl crl \
  -text \
  -noout \
  -in $home/crl/component-ca.crl

echo -e "\n\n##################  7. Publish Certificates"
echo -e "\n\n##################  7.1 Create DER certificate"
openssl x509 \
  -in $home/ca/root-ca.crt \
  -out $home/ca/root-ca.cer \
  -outform der
# All published certificates must be in DER format.
# MIME type: application/pkix-cert. [RFC 2585#section-4.1]
# https://tools.ietf.org/html/rfc2585.html#section-4.2

echo -e "\n\n##################  7.2 Create DER CRL"
openssl crl \
  -in $home/crl/network-ca.crl \
  -out $home/crl/network-ca.crl \
  -outform der
# All published CRLs must be in DER format.
# MIME type: application/pkix-crl. [RFC 2585#section-4.2]
# https://tools.ietf.org/html/rfc2585.html#section-4.2

echo -e "\n\n##################  7.3 Create PKCS#7 bundle"
openssl crl2pkcs7 -nocrl \
  -certfile $home/ca/identity-ca-chain.pem \
  -out $home/ca/identity-ca-chain.p7c \
  -outform der
# PKCS#7 is used to bundle two or more certificates.
# MIME type: application/pkcs7-mime. [RFC 5273#page-3]
# https://tools.ietf.org/html/rfc5273.html#page-3

tree $home
