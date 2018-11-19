#!/bin/bash

export home=$1  # This has to be a relative path from where you are
home=${home:-result_advanced}

if [ ! -d advanced-pki ]; then
  git clone https://github.com/itisnotdone/advanced-pki.git
  # replace dir variable from '.' to '$ENV::home' for all conf files
fi

echo -e "\n\n##################  1. Create Root CA"
echo -e "\n\n##################  1.1 Create directories"
mkdir -pv $home/ca/root-ca/{private,db} $home/{crl,certs,pp}
ln -sv $PWD/advanced-pki/etc $PWD/$home/etc
chmod 700 $home/ca/root-ca/private
# The ca directory holds CA resources, the crl directory holds CRLs, 
# and the certs directory holds user certificates.
# The directory layout stays the same throughout the tutorial.

echo -e "\n\n##################  1.2 Create database"
cp /dev/null $home/ca/root-ca/db/root-ca.db
cp /dev/null $home/ca/root-ca/db/root-ca.db.attr
echo 01 | tee $home/ca/root-ca/db/root-ca.crt.srl
echo 01 | tee $home/ca/root-ca/db/root-ca.crl.srl
# The files must exist before the openssl ca command can be used.
# Also see https://pki-tutorial.readthedocs.io/en/latest/cadb.html

echo -e "\n\n##################  Generate passphrase for root ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/root-ca-passphrase.txt

echo -e "\n\n##################  1.3 Create Root CSR"
openssl req -new \
  -passout file:$home/pp/root-ca-passphrase.txt \
  -config $home/etc/root-ca.conf \
  -out $home/ca/root-ca.csr \
  -keyout $home/ca/root-ca/private/root-ca.key
# With the openssl req -new command we create a private key and a CSR for the root CA.
# The configuration is taken from the [req] section of the root CA configuration file.

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
# With the openssl ca command we create a self-signed root certificate from the CSR.
# The configuration is taken from the [ca] section of the root CA configuration file.
# Note that we specify an end date based on the key length.
# 2048-bit RSA keys are deemed safe until 2030 (RSA Labs).

echo -e "\n\n##################  1.4.1 Print root CA certificate"
openssl x509 -text \
  -in $home/ca/root-ca.crt

echo -e "\n\n##################  1.5 Create root initial CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -config $home/etc/root-ca.conf \
  -out $home/crl/root-ca.crl
# With the openssl ca -gencrl command we generate an initial (empty) CRL.

echo -e "\n\n##################  2. Create Email CA"
echo -e "\n\n##################  2.1 Create directories"
mkdir -pv $home/ca/email-ca/{private,db}
chmod 700 $home/ca/email-ca/private

echo -e "\n\n##################  2.2 Create database"
cp /dev/null $home/ca/email-ca/db/email-ca.db
cp /dev/null $home/ca/email-ca/db/email-ca.db.attr
echo 01 | tee $home/ca/email-ca/db/email-ca.crt.srl
echo 01 | tee $home/ca/email-ca/db/email-ca.crl.srl

echo -e "\n\n##################  Generate passphrase for email ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/email-ca-passphrase.txt

echo -e "\n\n##################  2.3 Create Email CSR"
openssl req -new \
  -passout file:$home/pp/email-ca-passphrase.txt \
  -config $home/etc/email-ca.conf \
  -out $home/ca/email-ca.csr \
  -keyout $home/ca/email-ca/private/email-ca.key
# We create a private key and a CSR for the email CA.
# The configuration is taken from the [req] section of the email CA configuration file.

echo -e "\n\n##################  2.3.1 Print email CA private key"
openssl rsa \
  -text \
  -passin file:$home/pp/email-ca-passphrase.txt \
  -in $home/ca/email-ca/private/email-ca.key

echo -e "\n\n##################  2.3.2 Print Email CA CSR"
openssl req \
  -text \
  -in $home/ca/email-ca.csr \
  -noout

echo -e "\n\n##################  2.4 Create Email CA certificate"
openssl ca \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -batch \
  -config $home/etc/root-ca.conf \
  -in $home/ca/email-ca.csr \
  -out $home/ca/email-ca.crt \
  -extensions signing_ca_ext
# We use the root CA to issue the email CA certificate.
# Points if you noticed that -extensions could have been omitted.

echo -e "\n\n##################  2.4.1 Print Email CA certificate"
openssl x509 -text \
  -in $home/ca/email-ca.crt

echo -e "\n\n##################  2.5 Create email initial CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/email-ca-passphrase.txt \
  -config $home/etc/email-ca.conf \
  -out $home/crl/email-ca.crl
# We create an initial, empty CRL.

echo -e "\n\n##################  2.6 Create PEM bundle"
cat $home/ca/email-ca.crt $home/ca/root-ca.crt | tee \
  $home/ca/email-ca-chain.pem
# We create a certificate chain file from the email CA and root CA certificates.
# It will come handly later as input for the openssl pkcs12 command.

echo -e "\n\n##################  3. Create TLS CA"
echo -e "\n\n##################  3.1 Create directories"
mkdir -pv $home/ca/tls-ca/{private,db}
chmod 700 $home/ca/tls-ca/private

echo -e "\n\n##################  3.2 Create database"
cp /dev/null $home/ca/tls-ca/db/tls-ca.db
cp /dev/null $home/ca/tls-ca/db/tls-ca.db.attr
echo 01 | tee $home/ca/tls-ca/db/tls-ca.crt.srl
echo 01 | tee $home/ca/tls-ca/db/tls-ca.crl.srl

echo -e "\n\n##################  Generate passphrase for tls ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/tls-ca-passphrase.txt

echo -e "\n\n##################  3.3 Create tls CSR"
openssl req -new \
  -passout file:$home/pp/tls-ca-passphrase.txt \
  -config $home/etc/tls-ca.conf \
  -out $home/ca/tls-ca.csr \
  -keyout $home/ca/tls-ca/private/tls-ca.key
# We create a private key and a CSR for the TLS CA.
# The configuration is taken from the [req] section of the TLS CA configuration file.

echo -e "\n\n##################  3.3.1 Print tls CA private key"
openssl rsa \
  -text \
  -passin file:$home/pp/tls-ca-passphrase.txt \
  -in $home/ca/tls-ca/private/tls-ca.key

echo -e "\n\n##################  3.3.2 Print tls CA CSR"
openssl req \
  -text \
  -in $home/ca/tls-ca.csr \
  -noout

echo -e "\n\n##################  3.4 Create CA certificate"
openssl ca \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -batch \
  -config $home/etc/root-ca.conf \
  -in $home/ca/tls-ca.csr \
  -out $home/ca/tls-ca.crt \
  -extensions signing_ca_ext
# We use the root CA to issue the TLS CA certificate.

echo -e "\n\n##################  3.4.1 Print tls CA certificate"
openssl x509 -text \
  -in $home/ca/tls-ca.crt

echo -e "\n\n##################  3.5 Create tls initial CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/tls-ca-passphrase.txt \
  -config $home/etc/tls-ca.conf \
  -out $home/crl/tls-ca.crl
# We create an empty CRL.

echo -e "\n\n##################  3.6 Create PEM bundle"
cat $home/ca/tls-ca.crt $home/ca/root-ca.crt | tee \
  $home/ca/tls-ca-chain.pem
# We create a certificate chain file.

echo -e "\n\n##################  4. Create Software CA"
echo -e "\n\n##################  4.1 Create directories"
mkdir -pv  $home/ca/software-ca/{private,db}
chmod 700 $home/ca/software-ca/private

echo -e "\n\n##################  4.2 Create database"
cp /dev/null $home/ca/software-ca/db/software-ca.db
cp /dev/null $home/ca/software-ca/db/software-ca.db.attr
echo 01 | tee $home/ca/software-ca/db/software-ca.crt.srl
echo 01 | tee $home/ca/software-ca/db/software-ca.crl.srl

echo -e "\n\n##################  Generate passphrase for software ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/software-ca-passphrase.txt

echo -e "\n\n##################  4.3 Create software CSR"
openssl req -new \
  -passout file:$home/pp/software-ca-passphrase.txt \
  -config $home/etc/software-ca.conf \
  -out $home/ca/software-ca.csr \
  -keyout $home/ca/software-ca/private/software-ca.key
# We create a private key and a CSR for the software CA.
# The configuration is taken from the [req] section of the software CA configuration file.

echo -e "\n\n##################  4.3.1 Print software CA private key"
openssl rsa \
  -text \
  -passin file:$home/pp/software-ca-passphrase.txt \
  -in $home/ca/software-ca/private/software-ca.key

echo -e "\n\n##################  4.3.2 Print software CA CSR"
openssl req \
  -text \
  -in $home/ca/software-ca.csr \
  -noout

echo -e "\n\n##################  4.4 Create software CA certificate"
openssl ca \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -batch \
  -config $home/etc/root-ca.conf \
  -in $home/ca/software-ca.csr \
  -out $home/ca/software-ca.crt \
  -extensions signing_ca_ext
# We use the root CA to issue the software CA certificate.

echo -e "\n\n##################  4.4.1 Print software CA certificate"
openssl x509 -text \
  -in $home/ca/software-ca.crt

echo -e "\n\n##################  4.5 Create software initial CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/software-ca-passphrase.txt \
  -config $home/etc/software-ca.conf \
  -out $home/crl/software-ca.crl
# We create an empty CRL.

echo -e "\n\n##################  4.6 Create PEM bundle"
cat $home/ca/software-ca.crt $home/ca/root-ca.crt | tee \
  $home/ca/software-ca-chain.pem
# We create a certificate chain file.

echo -e "\n\n##################  5. Operate Email CA"

echo -e "\n\n##################  Generate passphrase for email fred ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/email-fred-passphrase.txt

echo -e "\n\n##################  5.1 Create email fred CSR"
openssl req -new \
  -passout file:$home/pp/email-fred-passphrase.txt \
  -config $home/etc/email.conf \
  -out $home/certs/fred.csr \
  -keyout $home/certs/fred.key
# We create the private key and CSR for an email-protection certificate using a request configuration file.
# When prompted enter these DN components: C=NO, O=Green AS, CN=Fred Flintstone, emailAddress=fred@green.no.
# Leave other fields empty.

echo -e "\n\n##################  5.1.1 Print email fred private key"
openssl rsa \
  -text \
  -passin file:$home/pp/email-fred-passphrase.txt \
  -in $home/certs/fred.key

echo -e "\n\n##################  5.1.2 Print email fred CSR"
openssl req \
  -text \
  -in $home/certs/fred.csr \
  -noout

echo -e "\n\n##################  5.2 Create email fred certificate"
openssl ca \
  -passin file:"$home"/pp/email-ca-passphrase.txt \
  -batch \
  -config $home/etc/email-ca.conf \
  -in $home/certs/fred.csr \
  -out $home/certs/fred.crt \
  -extensions email_ext
# We use the email CA to issue Fred’s email-protection certificate.
# A copy of the certificate is saved in the certificate archive under the name ca/email-ca/01.pem
# (01 being the certificate serial number in hex.)

echo -e "\n\n##################  5.2.1 Print email fred certificate"
openssl x509 -text \
  -in $home/certs/fred.crt

echo -e "\n\n##################  5.3 Create PKCS#12 bundle for email fred"
openssl pkcs12 -export \
  -passin file:"$home"/pp/email-fred-passphrase.txt \
  -password pass:blahblah \
  -name "Fred Flintstone (Email Security)" \
  -caname "Green Email CA" \
  -caname "Green Root CA" \
  -inkey $home/certs/fred.key \
  -in $home/certs/fred.crt \
  -certfile $home/ca/email-ca-chain.pem \
  -out $home/certs/fred.p12
# We pack the private key, the certificate, and the CA chain into a PKCS#12 bundle.
# This format (often with a .pfx extension) is used to distribute keys and certificates to end users.
# The friendly names help identify individual certificates within the bundle.

echo -e "\n\n##################  5.4 Revoke certificate"
openssl ca \
  -passin file:"$home"/pp/email-ca-passphrase.txt \
  -config $home/etc/email-ca.conf \
  -revoke $home/ca/email-ca/01.pem \
  -crl_reason keyCompromise
# When Fred’s laptop goes missing, we revoke his certificate.

echo -e "\n\n##################  5.5 Create CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/email-ca-passphrase.txt \
  -config $home/etc/email-ca.conf \
  -out $home/crl/email-ca.crl
# The next CRL contains the revoked certificate.

echo -e "\n\n##################  6. Operate TLS CA"

echo -e "\n\n##################  Generate passphrase for tls server"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/tls-server-passphrase.txt

echo -e "\n\n##################  6.1 Create TLS server request"
SAN=DNS:green.no,DNS:www.green.no \
openssl req -new \
  -passout file:$home/pp/tls-server-passphrase.txt \
  -config $home/etc/server.conf \
  -out $home/certs/green.no.csr \
  -keyout $home/certs/green.no.key
# We create the private key and CSR for a TLS-server certificate using the appropriate request configuration file.
# When prompted enter these DN components: C=NO, O=Green AS, CN=www.green.no.
# The subjectAltName cannot be prompted for and must be specified as environment variable.

echo -e "\n\n##################  6.1.1 Print tls server private key"
openssl rsa \
  -text \
  -passin file:$home/pp/tls-server-passphrase.txt \
  -in $home/certs/green.no.key

echo -e "\n\n##################  6.1.2 Print tls server CSR"
openssl req \
  -text \
  -in $home/certs/green.no.csr \
  -noout

echo -e "\n\n##################  6.2 Create TLS server certificate"
openssl ca \
  -passin file:"$home"/pp/tls-ca-passphrase.txt \
  -batch \
  -config $home/etc/tls-ca.conf \
  -in $home/certs/green.no.csr \
  -out $home/certs/green.no.crt \
  -extensions server_ext
# We use the TLS CA to issue the server certificate.

echo -e "\n\n##################  6.2.1 Print tls server certificate"
openssl x509 -text \
  -in $home/certs/green.no.crt

echo -e "\n\n##################  6.3 Create tls server PKCS#12 bundle"
openssl pkcs12 -export \
  -passin file:"$home"/pp/tls-server-passphrase.txt \
  -password pass:blahblah \
  -name "green.no (Network Component)" \
  -caname "Green TLS CA" \
  -caname "Green Root CA" \
  -inkey $home/certs/green.no.key \
  -in $home/certs/green.no.crt \
  -certfile $home/ca/tls-ca-chain.pem \
  -out $home/certs/green.no.p12
# We pack the private key, the certificate, and the CA chain into a PKCS#12 bundle for distribution.

echo -e "\n\n##################  Generate passphrase for tls client"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/tls-client-passphrase.txt

echo -e "\n\n##################  6.4 Create TLS client request"
openssl req -new \
  -passout file:$home/pp/tls-client-passphrase.txt \
  -config $home/etc/client.conf \
  -out $home/certs/barney.csr \
  -keyout $home/certs/barney.key
# We create the private key and CSR for a TLS-client certificate using the client request configuration file.
# When prompted enter these DN components: C=NO, O=Telenor AS, OU=Support, CN=Barney Rubble, emailAddress=barney@telenor.no.

echo -e "\n\n##################  6.4.1 Print tls client private key"
openssl rsa \
  -text \
  -passin file:$home/pp/tls-client-passphrase.txt \
  -in $home/certs/barney.key

echo -e "\n\n##################  6.4.2 Print tls client CSR"
openssl req \
  -text \
  -in $home/certs/barney.csr \
  -noout

echo -e "\n\n##################  6.5 Create TLS client certificate"
openssl ca \
  -passin file:"$home"/pp/tls-ca-passphrase.txt \
  -batch \
  -config $home/etc/tls-ca.conf \
  -in $home/certs/barney.csr \
  -out $home/certs/barney.crt \
  -policy extern_pol \
  -extensions client_ext
# We use the TLS CA to issue Barney’s client certificate.
# Note that we must specify the ‘extern’ naming policy
# because the DN would not satisfy the default ‘match’ policy.

echo -e "\n\n##################  6.5.1 Print tls client certificate"
openssl x509 -text \
  -in $home/certs/barney.crt

echo -e "\n\n##################  6.6 Create tls client PKCS#12 bundle"
openssl pkcs12 -export \
  -passin file:"$home"/pp/tls-client-passphrase.txt \
  -password pass:blahblah \
  -name "Barney Rubble (Network Access)" \
  -caname "Green TLS CA" \
  -caname "Green Root CA" \
  -inkey $home/certs/barney.key \
  -in $home/certs/barney.crt \
  -certfile $home/ca/tls-ca-chain.pem \
  -out $home/certs/barney.p12
# We pack everything up into a PKCS#12 bundle for distribution.

echo -e "\n\n##################  6.7 Revoke certificate"
openssl ca \
  -passin file:"$home"/pp/tls-ca-passphrase.txt \
  -config $home/etc/tls-ca.conf \
  -revoke $home/ca/tls-ca/02.pem \
  -crl_reason affiliationChanged
# When the support contract ends, we revoke the certificate.

echo -e "\n\n##################  6.8 Create CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/tls-ca-passphrase.txt \
  -config $home/etc/tls-ca.conf \
  -out $home/crl/tls-ca.crl
# The next CRL contains the revoked certificate.

echo -e "\n\n##################  7. Operate Software CA"

echo -e "\n\n##################  Generate passphrase for code-signing crt"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/codesign-passphrase.txt

echo -e "\n\n##################  7.1 Create code-signing request"
openssl req -new \
  -passout file:$home/pp/codesign-passphrase.txt \
  -config $home/etc/codesign.conf \
  -out $home/certs/software.csr \
  -keyout $home/certs/software.key
# We create the private key and CSR for a code-signing certificate using another request configuration file.
# When prompted enter these DN components: C=NO, O=Green AS, OU=Green Certificate Authority, CN=Green Software Certificate.

echo -e "\n\n##################  7.1.1 Print codesign private key"
openssl rsa \
  -text \
  -passin file:$home/pp/codesign-passphrase.txt \
  -in $home/certs/software.key

echo -e "\n\n##################  7.1.2 Print codesign CSR"
openssl req \
  -text \
  -in $home/certs/software.csr \
  -noout

echo -e "\n\n##################  7.2 Create code-signing certificate"
openssl ca \
  -passin file:"$home"/pp/software-ca-passphrase.txt \
  -batch \
  -config $home/etc/software-ca.conf \
  -in $home/certs/software.csr \
  -out $home/certs/software.crt \
  -extensions codesign_ext
# We use the software CA to issue the code-signing certificate.

echo -e "\n\n##################  7.2.1 Print codesign certificate"
openssl x509 -text \
  -in $home/certs/software.crt

echo -e "\n\n##################  7.3 Create PKCS#12 bundle"
openssl pkcs12 -export \
  -passin file:"$home"/pp/codesign-passphrase.txt \
  -password pass:blahblah \
  -name "Green Software Certificate" \
  -caname "Green Software CA" \
  -caname "Green Root CA" \
  -inkey $home/certs/software.key \
  -in $home/certs/software.crt \
  -certfile $home/ca/software-ca-chain.pem \
  -out $home/certs/software.p12
# We create a PKCS#12 bundle for distribution.

echo -e "\n\n##################  7.4 Revoke certificate"
openssl ca \
  -passin file:"$home"/pp/software-ca-passphrase.txt \
  -config $home/etc/software-ca.conf \
  -revoke $home/ca/software-ca/01.pem \
  -crl_reason unspecified
# To complete the example, we revoke the software certificate.

echo -e "\n\n##################  7.5 Create CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/software-ca-passphrase.txt \
  -config $home/etc/software-ca.conf \
  -out $home/crl/software-ca.crl
# The next CRL contains the revoked certificate.

echo -e "\n\n##################  8. Publish Certificates"
echo -e "\n\n##################  8.1 Create DER certificate"
openssl x509 \
  -in $home/ca/root-ca.crt \
  -out $home/ca/root-ca.cer \
  -outform der
# All published certificates must be in DER format.
# MIME type: application/pkix-cert. [RFC 2585#section-4.1]

echo -e "\n\n##################  8.2 Create DER CRL"
openssl crl \
  -in $home/crl/email-ca.crl \
  -out $home/crl/email-ca.crl \
  -outform der
# All published CRLs must be in DER format.
# MIME type: application/pkix-crl. [RFC 2585#section-4.2]

echo -e "\n\n##################  8.3 Create PKCS#7 bundle"
openssl crl2pkcs7 -nocrl \
  -certfile $home/ca/email-ca-chain.pem \
  -out $home/ca/email-ca-chain.p7c \
  -outform der
# PKCS#7 is used to bundle two or more certificates.
# MIME type: application/pkcs7-mime. [RFC 5273#page-3]

tree $home
