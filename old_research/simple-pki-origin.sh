#!/bin/bash

echo -e "\n\n##################  1. Create Root CA"
echo -e "\n\n##################  1.1 Create directories"
mkdir -p ca/root-ca/private ca/root-ca/db crl certs
chmod 700 ca/root-ca/private
# The ca directory holds CA resources, the crl directory holds CRLs,
# and the certs directory holds user certificates.

echo -e "\n\n##################  1.2 Create database"
cp /dev/null ca/root-ca/db/root-ca.db
cp /dev/null ca/root-ca/db/root-ca.db.attr
echo 01 > ca/root-ca/db/root-ca.crt.srl
echo 01 > ca/root-ca/db/root-ca.crl.srl
# The database files must exist before the openssl ca command can be used.
# The file contents are described in Appendix B: CA Database.
# https://pki-tutorial.readthedocs.io/en/latest/cadb.html

echo -e "\n\n##################  1.3 Create CA request"
openssl req -new \
  -config etc/root-ca.conf \
  -out ca/root-ca.csr \
  -keyout ca/root-ca/private/root-ca.key
# With the openssl req -new command we create a private key
# and a certificate signing request (CSR) for the root CA.
# You will be asked for a passphrase to protect the private key.
# The openssl req command takes its configuration from
# the [req] section of the configuration file.

echo -e "\n\n##################  1.4 Create CA certificate"
openssl ca -selfsign \
  -config etc/root-ca.conf \
  -in ca/root-ca.csr \
  -out ca/root-ca.crt \
  -extensions root_ca_ext
# With the openssl ca command we issue a root CA certificate based on the CSR.
# The root certificate is self-signed and serves as the starting point for
# all trust relationships in the PKI. The openssl ca command takes
# its configuration from the [ca] section of the configuration file.

echo -e "\n\n##################  2. Create Signing CA"
echo -e "\n\n##################  2.1 Create directories"
mkdir -p ca/signing-ca/private ca/signing-ca/db crl certs
chmod 700 ca/signing-ca/private
# The ca directory holds CA resources, the crl directory holds CRLs,
# and the certs directory holds user certificates.
# We will use this layout for all CAs in this tutorial.

echo -e "\n\n##################  2.2 Create database"
cp /dev/null ca/signing-ca/db/signing-ca.db
cp /dev/null ca/signing-ca/db/signing-ca.db.attr
echo 01 > ca/signing-ca/db/signing-ca.crt.srl
echo 01 > ca/signing-ca/db/signing-ca.crl.srl
# The contents of these files are described in Appendix B: CA Database.
# https://pki-tutorial.readthedocs.io/en/latest/cadb.html

echo -e "\n\n##################  2.3 Create CA request"
openssl req -new \
  -config etc/signing-ca.conf \
  -out ca/signing-ca.csr \
  -keyout ca/signing-ca/private/signing-ca.key
# With the openssl req -new command we create a private key and a CSR for the signing CA.
# You will be asked for a passphrase to protect the private key.
# The openssl req command takes its configuration from
# the [req] section of the configuration file.

echo -e "\n\n##################  2.4 Create CA certificate"
openssl ca \
  -config etc/root-ca.conf \
  -in ca/signing-ca.csr \
  -out ca/signing-ca.crt \
  -extensions signing_ca_ext
# With the openssl ca command we issue a certificate based on the CSR.
# The command takes its configuration from the [ca] section of the configuration file.
# Note that it is the root CA that issues the signing CA certificate!
# Note also that we attach a different set of extensions.

echo -e "\n\n##################  3. Operate Signing CA"
echo -e "\n\n##################  3.1 Create email request"
openssl req -new \
  -config etc/email.conf \
  -out certs/fred.csr \
  -keyout certs/fred.key
# With the openssl req -new command we create the private key and
# CSR for an email-protection certificate.
# We use a request configuration file specifically prepared for the task.
# When prompted enter these DN components:
# DC=org, DC=simple, O=Simple Inc, CN=Fred Flintstone, emailAddress=fred@simple.org
# Leave other fields empty.

echo -e "\n\n##################  3.2 Create email certificate"
openssl ca \
  -config etc/signing-ca.conf \
  -in certs/fred.csr \
  -out certs/fred.crt \
  -extensions email_ext
# We use the signing CA to issue the email-protection certificate.
# The certificate type is defined by the extensions we attach.
# A copy of the certificate is saved in the certificate archive
# under the name ca/signing-ca/01.pem
# (01 being the certificate serial number in hex.)

echo -e "\n\n##################  3.3 Create TLS server request"
SAN=DNS:www.simple.org \
openssl req -new \
  -config etc/server.conf \
  -out certs/simple.org.csr \
  -keyout certs/simple.org.key
# Next we create the private key and CSR for a TLS-server certificate using
# another request configuration file.
# When prompted enter these DN components:
# DC=org, DC=simple, O=Simple Inc, CN=www.simple.org
# Note that the subjectAltName must be specified as environment variable.
# Note also that server keys typically have no passphrase.

echo -e "\n\n##################  3.4 Create TLS server certificate"
openssl ca \
  -config etc/signing-ca.conf \
  -in certs/simple.org.csr \
  -out certs/simple.org.crt \
  -extensions server_ext
# We use the signing CA to issue the server certificate.
# The certificate type is defined by the extensions we attach.
# A copy of the certificate is saved in the certificate archive under
# the name ca/signing-ca/02.pem.

echo -e "\n\n##################  3.5 Revoke certificate"
openssl ca \
  -config etc/signing-ca.conf \
  -revoke ca/signing-ca/01.pem \
  -crl_reason superseded
# Certain events, like certificate replacement or loss of private key,
# require a certificate to be revoked before its scheduled expiration date.
# The openssl ca -revoke command marks a certificate as revoked in the CA database.
# It will from then on be included in CRLs issued by the CA.
# The above command revokes the certificate with serial number 01 (hex).

echo -e "\n\n##################  3.6 Create CRL"
openssl ca -gencrl \
  -config etc/signing-ca.conf \
  -out crl/signing-ca.crl
# The openssl ca -gencrl command creates a certificate revocation list (CRL).
# The CRL contains all revoked, not-yet-expired certificates from the CA database.
# A new CRL must be issued at regular intervals.


echo -e "\n\n##################  4. Output Formats"
echo -e "\n\n##################  4.1 Create DER certificate"
openssl x509 \
  -in certs/fred.crt \
  -out certs/fred.cer \
  -outform der
# All published certificates must be in DER format [RFC 2585#section-3].
# Also see Appendix A: MIME Types.
# https://pki-tutorial.readthedocs.io/en/latest/mime.html

echo -e "\n\n##################  4.2 Create DER CRL"
openssl crl \
  -in crl/signing-ca.crl \
  -out crl/signing-ca.crl \
  -outform der
# All published CRLs must be in DER format [RFC 2585#section-3].
# Also see Appendix A: MIME Types.
# https://pki-tutorial.readthedocs.io/en/latest/mime.html

echo -e "\n\n##################  4.3 Create PKCS#7 bundle"
openssl crl2pkcs7 -nocrl \
  -certfile ca/signing-ca.crt \
  -certfile ca/root-ca.crt \
  -out ca/signing-ca-chain.p7c \
  -outform der
# PKCS#7 is used to bundle two or more certificates.
# The format would also allow for CRLs but they are not used in practice.

echo -e "\n\n##################  4.4 Create PKCS#12 bundle"
openssl pkcs12 -export \
  -name "Fred Flintstone" \
  -inkey certs/fred.key \
  -in certs/fred.crt \
  -out certs/fred.p12
# PKCS#12 is used to bundle a certificate and its private key.
# Additional certificates may be added, typically the certificates comprising
# the chain up to the Root CA.

echo -e "\n\n##################  4.5 Create PEM bundle"
cat ca/signing-ca.crt ca/root-ca.crt > \
  ca/signing-ca-chain.pem

cat certs/fred.key certs/fred.crt > \
  certs/fred.pem
# PEM bundles are created by concatenating other PEM-formatted files.
# The most common forms are “cert chain”, “key + cert”, and “key + cert chain”.
# PEM bundles are supported by OpenSSL and most software based on it.
# (e.g. Apache mod_ssl and stunnel.)

echo -e "\n\n##################  5. View Results"
echo -e "\n\n##################  5.1 View request"
openssl req \
  -in certs/fred.csr \
  -noout \
  -text
# The openssl req command can be used to display the contents of CSR files.
# The -noout and -text options select a human-readable output format.

echo -e "\n\n##################  5.2 View certificate"
openssl x509 \
  -in certs/fred.crt \
  -noout \
  -text
# The openssl x509 command can be used to display the contents of certificate files.
# The -noout and -text options have the same purpose as before.

echo -e "\n\n##################  5.3 View CRL"
openssl crl \
  -in crl/signing-ca.crl \
  -inform der \
  -noout \
  -text
# The openssl crl command can be used to view the contents of CRL files.
# Note that we specify -inform der because we have already converted the CRL in step 4.2.

echo -e "\n\n##################  5.4 View PKCS#7 bundle"
openssl pkcs7 \
  -in ca/signing-ca-chain.p7c \
  -inform der \
  -noout \
  -text \
  -print_certs
# The openssl pkcs7 command can be used to display the contents of PKCS#7 bundles.

echo -e "\n\n##################  5.5 View PKCS#12 bundle"
openssl pkcs12 \
  -in certs/fred.p12 \
  -nodes \
  -info
# The openssl pkcs12 command can be used to display the contents of PKCS#12 bundles.
