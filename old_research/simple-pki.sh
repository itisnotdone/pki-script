#!/bin/bash

# bash -x simple-pki.sh intra.example.org

export CN=$1

export DC0=`echo $CN | awk -F '.' '{print $3}'`
export DC1=`echo $CN | awk -F '.' '{print $2}'`
export DC2=`echo $CN | awk -F '.' '{print $1}'`
export SAN="\
  DNS:$CN,\
  DNS:*.$CN,\
  DNS:dev$CN,\
  DNS:*.dev$CN,\
  DNS:test$CN,\
  DNS:*.test$CN,\
  DNS:stg$CN,\
  DNS:*.stg$CN"
export ON="${DC1^}"
export OUN="${DC1^} ${DC2^}"
export home=$CN  # This has to be a relative path from where you are

if [ ! -d simple-pki ]; then
  git clone https://github.com/itisnotdone/simple-pki.git
  # replace dir variable from '.' to '$ENV::home' for all conf files
fi

echo -e "\n\n##################  1. Create Root CA"
echo -e "\n\n##################  1.1 Create directories"
mkdir -pv $home/ca/root-ca/{private,db} $home/{crl,certs,pp}
ln -sv $PWD/simple-pki/etc $PWD/$home/etc
chmod 700 $home/ca/root-ca/private
# The ca directory holds CA resources, the crl directory holds CRLs,
# and the certs directory holds user certificates.

echo -e "\n\n##################  1.2 Create database"
cp /dev/null $home/ca/root-ca/db/root-ca.db
cp /dev/null $home/ca/root-ca/db/root-ca.db.attr
echo 01 | tee $home/ca/root-ca/db/root-ca.crt.srl
echo 01 | tee $home/ca/root-ca/db/root-ca.crl.srl
# The database files must exist before the openssl ca command can be used.
# The file contents are described in Appendix B: CA Database.
# https://pki-tutorial.readthedocs.io/en/latest/cadb.html

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
# With the openssl req -new command we create a private key
# and a certificate signing request (CSR) for the root CA.
# You will be asked for a passphrase to protect the private key.
# The openssl req command takes its configuration from
# the [req] section of the configuration file.

# echo -e "\n\n##################  1.3.1 Print root CA private key"
# openssl rsa \
#   -text \
#   -passin file:$home/pp/root-ca-passphrase.txt \
#   -in $home/ca/root-ca/private/root-ca.key

echo -e "\n\n##################  1.3.2 Print root CA CSR"
openssl req \
  -text \
  -in $home/ca/root-ca.csr \
  -noout

echo -e "\n\n##################  1.4 Create root CA certificate"
openssl ca -selfsign \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -batch \
  -config $home/etc/root-ca.conf \
  -in $home/ca/root-ca.csr \
  -out $home/ca/root-ca.crt \
  -extensions root_ca_ext
# With the openssl ca command we issue a root CA certificate based on the CSR.
# The root certificate is self-signed and serves as the starting point for
# all trust relationships in the PKI. The openssl ca command takes
# its configuration from the [ca] section of the configuration file.

echo -e "\n\n##################  1.4.1 Print root CA certificate"
openssl x509 -text \
  -in $home/ca/root-ca.crt

echo -e "\n\n##################  2. Create Signing CA"
echo -e "\n\n##################  2.1 Create directories"
mkdir -pv $home/ca/signing-ca/{private,db}
chmod 700 $home/ca/signing-ca/private
# The ca directory holds CA resources, the crl directory holds CRLs,
# and the certs directory holds user certificates.
# We will use this layout for all CAs in this tutorial.

echo -e "\n\n##################  2.2 Create database"
cp /dev/null $home/ca/signing-ca/db/signing-ca.db
cp /dev/null $home/ca/signing-ca/db/signing-ca.db.attr
echo 01 | tee $home/ca/signing-ca/db/signing-ca.crt.srl
echo 01 | tee $home/ca/signing-ca/db/signing-ca.crl.srl
# The contents of these files are described in Appendix B: CA Database.
# https://pki-tutorial.readthedocs.io/en/latest/cadb.html

echo -e "\n\n##################  Generate passphrase for signing ca"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/signing-ca-passphrase.txt

echo -e "\n\n##################  2.3 Create signing CSR"
openssl req -new \
  -passout file:$home/pp/signing-ca-passphrase.txt \
  -config $home/etc/signing-ca.conf \
  -out $home/ca/signing-ca.csr \
  -keyout $home/ca/signing-ca/private/signing-ca.key
# With the openssl req -new command we create a private key and a CSR for the signing CA.
# You will be asked for a passphrase to protect the private key.
# The openssl req command takes its configuration from
# the [req] section of the configuration file.

# echo -e "\n\n##################  2.3.1 Print signing ca private key"
# openssl rsa \
#   -text \
#   -passin file:$home/pp/signing-ca-passphrase.txt \
#   -in $home/ca/signing-ca/private/signing-ca.key

echo -e "\n\n##################  2.3.2 Print signing CA CSR"
openssl req \
  -text \
  -in $home/ca/signing-ca.csr \
  -noout

echo -e "\n\n##################  2.4 Create signing CA certificate"
openssl ca \
  -passin file:"$home"/pp/root-ca-passphrase.txt \
  -batch \
  -config $home/etc/root-ca.conf \
  -in $home/ca/signing-ca.csr \
  -out $home/ca/signing-ca.crt \
  -extensions signing_ca_ext
# With the openssl ca command we issue a certificate based on the CSR.
# The command takes its configuration from the [ca] section of the configuration file.
# Note that it is the root CA that issues the signing CA certificate!
# Note also that we attach a different set of extensions.

echo -e "\n\n##################  2.4.1 Print signing CA certificate"
openssl x509 -text \
  -in $home/ca/signing-ca.crt

echo -e "\n\n##################  3. Operate Signing CA"

#   echo -e "\n\n##################  Generate passphrase for email client"
#   openssl rand \
#     -base64 48 \
#     | tee "$home"/pp/email-client-passphrase.txt
#   
#   echo -e "\n\n##################  3.1 Create email client CSR"
#   openssl req -new \
#     -passout file:$home/pp/email-client-passphrase.txt \
#     -config $home/etc/email.conf \
#     -out $home/certs/fred.csr \
#     -keyout $home/certs/fred.key
#   # With the openssl req -new command we create the private key and
#   # CSR for an email-protection certificate.
#   # We use a request configuration file specifically prepared for the task.
#   # When prompted enter these DN components:
#   # DC=org, DC=simple, O=Simple Inc, CN=Fred Flintstone, emailAddress=fred@$CN
#   # Leave other fields empty.
#   
#   # echo -e "\n\n##################  3.1.1 Print email client private key"
#   # openssl rsa \
#   #   -text \
#   #   -passin file:$home/pp/email-client-passphrase.txt \
#   #   -in $home/certs/fred.key
#   
#   echo -e "\n\n##################  3.1.2 Print email client CSR"
#   openssl req \
#     -text \
#     -in $home/certs/fred.csr \
#     -noout
#   
#   echo -e "\n\n##################  3.2 Create email certificate"
#   openssl ca \
#     -passin file:"$home"/pp/signing-ca-passphrase.txt \
#     -batch \
#     -config $home/etc/signing-ca.conf \
#     -in $home/certs/fred.csr \
#     -out $home/certs/fred.crt \
#     -extensions email_ext
#   # We use the signing CA to issue the email-protection certificate.
#   # The certificate type is defined by the extensions we attach.
#   # A copy of the certificate is saved in the certificate archive
#   # under the name ca/signing-ca/01.pem
#   # (01 being the certificate serial number in hex.)
#   
#   echo -e "\n\n##################  3.2.1 Print email client certificate"
#   openssl x509 -text \
#     -in $home/certs/fred.crt

echo -e "\n\n##################  Generate passphrase for tls server"
openssl rand \
  -base64 48 \
  | tee "$home"/pp/"$CN"-passphrase.txt

echo -e "\n\n##################  3.3 Create TLS server CSR"
openssl req -new \
  -passout file:$home/pp/"$CN"-passphrase.txt \
  -config $home/etc/server.conf \
  -out $home/certs/$CN.csr \
  -keyout $home/certs/encrypted_$CN.key
# Next we create the private key and CSR for a "$CN" certificate using
# another request configuration file.
# When prompted enter these DN components:
# DC=org, DC=simple, O=Simple Inc, CN=www.$CN
# Note that the subjectAltName must be specified as environment variable.
# Note also that server keys typically have no passphrase.

echo -e "\n\n##################  3.3 Extract plain private key"
openssl rsa \
  -passin file:$home/pp/"$CN"-passphrase.txt \
  -in $home/certs/encrypted_$CN.key \
  -out $home/certs/$CN.key

# echo -e "\n\n##################  3.3.1 Print tls server private key"
# openssl rsa \
#   -text \
#   -passin file:$home/pp/"$CN"-passphrase.txt \
#   -in $home/certs/encrypted_$CN.key

echo -e "\n\n##################  3.3.2 Print tls server CSR"
openssl req \
  -text \
  -in $home/certs/$CN.csr \
  -noout

echo -e "\n\n##################  3.4 Create TLS server certificate"
openssl ca \
  -passin file:"$home"/pp/signing-ca-passphrase.txt \
  -batch \
  -config $home/etc/signing-ca.conf \
  -in $home/certs/$CN.csr \
  -out $home/certs/$CN.crt \
  -extensions server_ext
# We use the signing CA to issue the server certificate.
# The certificate type is defined by the extensions we attach.
# A copy of the certificate is saved in the certificate archive under
# the name ca/signing-ca/02.pem.

echo -e "\n\n##################  3.4.1 Print tls server certificate"
openssl x509 -text \
  -in $home/certs/$CN.crt

echo -e "\n\n##################  3.5 Revoke certificate"
openssl ca \
  -passin file:"$home"/pp/signing-ca-passphrase.txt \
  -config $home/etc/signing-ca.conf \
  -revoke $home/ca/signing-ca/01.pem \
  -crl_reason superseded
# Certain events, like certificate replacement or loss of private key,
# require a certificate to be revoked before its scheduled expiration date.
# The openssl ca -revoke command marks a certificate as revoked in the CA database.
# It will from then on be included in CRLs issued by the CA.
# The above command revokes the certificate with serial number 01 (hex).

echo -e "\n\n##################  3.6 Create CRL"
openssl ca -gencrl \
  -passin file:"$home"/pp/signing-ca-passphrase.txt \
  -config $home/etc/signing-ca.conf \
  -out $home/crl/signing-ca.crl
# The openssl ca -gencrl command creates a certificate revocation list (CRL).
# The CRL contains all revoked, not-yet-expired certificates from the CA database.
# A new CRL must be issued at regular intervals.


#    echo -e "\n\n##################  4. Output Formats"
#    echo -e "\n\n##################  4.1 Create DER certificate"
#    openssl x509 \
#      -in $home/certs/fred.crt \
#      -out $home/certs/fred.cer \
#      -outform der
#    # All published certificates must be in DER format [RFC 2585#section-3].
#    # Also see Appendix A: MIME Types.
#    # https://pki-tutorial.readthedocs.io/en/latest/mime.html

echo -e "\n\n##################  4.2 Create DER CRL"
openssl crl \
  -in $home/crl/signing-ca.crl \
  -out $home/crl/signing-ca.crl \
  -outform der
# All published CRLs must be in DER format [RFC 2585#section-3].
# Also see Appendix A: MIME Types.
# https://pki-tutorial.readthedocs.io/en/latest/mime.html

echo -e "\n\n##################  4.3 Create PKCS#7 bundle"
openssl crl2pkcs7 -nocrl \
  -certfile $home/ca/signing-ca.crt \
  -certfile $home/ca/root-ca.crt \
  -out $home/ca/signing-ca-chain.p7c \
  -outform der
# PKCS#7 is used to bundle two or more certificates.
# The format would also allow for CRLs but they are not used in practice.

#    echo -e "\n\n##################  4.4 Create PKCS#12 bundle"
#    openssl pkcs12 -export \
#      -passin file:"$home"/pp/email-client-passphrase.txt \
#      -password pass:blahblah \
#      -name "Fred Flintstone" \
#      -inkey $home/certs/fred.key \
#      -in $home/certs/fred.crt \
#      -out $home/certs/fred.p12
#    # PKCS#12 is used to bundle a certificate and its private key.
#    # Additional certificates may be added, typically the certificates comprising
#    # the chain up to the Root CA.

echo -e "\n\n##################  4.5 Create PEM bundle"
cat $home/ca/signing-ca.crt $home/ca/root-ca.crt | tee \
  $home/ca/signing-ca-chain.pem

#    cat $home/certs/fred.key $home/certs/fred.crt | tee \
#      $home/certs/fred.pem
#    # PEM bundles are created by concatenating other PEM-formatted files.
#    # The most common forms are “cert chain”, “key + cert”, and “key + cert chain”.
#    # PEM bundles are supported by OpenSSL and most software based on it.
#    # (e.g. Apache mod_ssl and stunnel.)

#    echo -e "\n\n##################  5. View Results"
#    echo -e "\n\n##################  5.1 View request"
#    openssl req \
#      -passout file:$home/pp/email-client-passphrase.txt \
#      -in $home/certs/fred.csr \
#      -noout \
#      -text
#    # The openssl req command can be used to display the contents of CSR files.
#    # The -noout and -text options select a human-readable output format.
#    
#    echo -e "\n\n##################  5.2 View certificate"
#    openssl x509 \
#      -in $home/certs/fred.crt \
#      -noout \
#      -text
#    # The openssl x509 command can be used to display the contents of certificate files.
#    # The -noout and -text options have the same purpose as before.

echo -e "\n\n##################  5.3 View CRL"
openssl crl \
  -in $home/crl/signing-ca.crl \
  -inform der \
  -noout \
  -text
# The openssl crl command can be used to view the contents of CRL files.
# Note that we specify -inform der because we have already converted the CRL in step 4.2.

echo -e "\n\n##################  5.4 View PKCS#7 bundle"
openssl pkcs7 \
  -in $home/ca/signing-ca-chain.p7c \
  -inform der \
  -noout \
  -text \
  -print_certs
# The openssl pkcs7 command can be used to display the contents of PKCS#7 bundles.

#    echo -e "\n\n##################  5.5 View PKCS#12 bundle"
#    openssl pkcs12 \
#      -password pass:blahblah \
#      -in $home/certs/fred.p12 \
#      -nodes \
#      -info
#    # The openssl pkcs12 command can be used to display the contents of PKCS#12 bundles.

tree $home
