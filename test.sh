#!/bin/bash

source pki/etc/profile_ca
source pki/etc/profile_site

# create cert dir
mkdir certs

TARGET=$PKI_SERVICE_DOMAIN

function download_certs {

  curl -o certs/root_ca.crt \
    http://$TARGET/site/root_ca.crt
  curl -o certs/signing_ca.crt \
    http://$TARGET/site/signing_ca.crt
  curl -o certs/ca-bundle.crt \
    http://$TARGET/site/ca-bundle.crt
  curl -o certs/site.crt \
    http://$TARGET/site/$DOMAIN"_"$(date +%Y).crt

  echo "##################################################################"
  echo
}

function update_systemwide_ca_certs {

  sudo rm /usr/local/share/ca-certificates/*
  sudo update-ca-certificates --fresh

  sudo cp -v certs/ca-bundle.crt \
    /usr/local/share/ca-certificates/ca-bundle.crt
  sudo update-ca-certificates

  echo "##################################################################"
  echo
}

function update_firefox_ca_certs {
  if ! dpkg -s libnss3-tools > /dev/null 2>&1; then sudo apt install -y libnss3-tools; fi
  if ! dpkg -s firefox > /dev/null 2>&1; then sudo apt install -y firefox; fi

  for certDB in $(find  ~/.mozilla* -name "cert8.db")
  do
    certDir=$(dirname $certDB);
    #log "mozilla certificate" "install '${certificateName}' in ${certDir}"
    certutil -L -d sql:$certDir
    certutil -D -d sql:$certDir -n "$ROOT_CA_DN_O"
    certutil -D -d sql:$certDir -n "$SIGNING_CA_DN_CN"
    certutil -L -d sql:$certDir
    certutil -A -d sql:$certDir -n "$ROOT_CA_DN_O" -t "TCu,Cuw,Tuw" -i certs/root_ca.crt
    certutil -A -d sql:$certDir -n "$SIGNING_CA_DN_CN" -t "TCu,Cuw,Tuw" -i certs/signing_ca.crt
    certutil -L -d sql:$certDir
  done

  echo "##################################################################"
  echo
}

function update_chrome_ca_certs {
  if ! dpkg -s libnss3-tools > /dev/null 2>&1; then sudo apt install -y libnss3-tools; fi
  if ! dpkg -s google-chrome-stable > /dev/null 2>&1
  then
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | \
      sudo tee /etc/apt/sources.list.d/google-chrome.list
    sudo apt update
    sudo apt install -y google-chrome-stable
  fi

  [ -d ~/.pki/nssdb ] || mkdir -p ~/.pki/nssdb
  certutil -L -d sql:$HOME/.pki/nssdb
  certutil -D -d sql:$HOME/.pki/nssdb -n "$ROOT_CA_DN_O" -i certs/root_ca.crt -t TCu,Cuw,Tuw
  certutil -L -d sql:$HOME/.pki/nssdb
  certutil -A -d sql:$HOME/.pki/nssdb -n "$ROOT_CA_DN_O" -i certs/root_ca.crt -t TCu,Cuw,Tuw
  certutil -L -d sql:$HOME/.pki/nssdb

  echo "##################################################################"
  echo
}

function setup {

  download_certs
  update_systemwide_ca_certs
  update_firefox_ca_certs
  update_chrome_ca_certs

}

function tests {
  echo "Connecting to SSL Services"
  echo | openssl s_client -connect $TARGET:443
  echo

  echo "Using Different Handshake Formats"
  echo | openssl s_client -connect $TARGET:443 -no_ssl2
  echo

  echo "Extracting Remote Certificates"
  echo | openssl s_client -connect $TARGET:443 2>&1 | sed --quiet '
  /-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > certs/$DOMAIN.crt
  echo

  echo "Testing Protocol Support"
  echo | openssl s_client -connect $TARGET:443 -tls1_2
  echo | openssl s_client -connect $TARGET:443 -tls1_1
  echo

  echo "Testing Cipher Suite Support"
  echo | openssl s_client -connect $TARGET:443 -cipher RC4-SHA  # will fail
  echo | openssl s_client -connect $TARGET:443 -cipher ECDHE-RSA-AES256-SHA
  echo

  echo "Testing Session Reuse"
  echo | openssl s_client -connect $TARGET:443 -reconnect
  echo | openssl s_client -connect $TARGET:443 -reconnect -no_ssl2 2> \
    /dev/null | grep 'New\|Reuse'
  echo

  # # Checking OCSP Revocation
  # echo | openssl s_client -connect $TARGET:443 -showcerts
  # openssl ocsp \
  #   -issuer certs/signing_ca.crt \
  #   -cert certs/site.crt \
  #   -url http://$TARGET:9081 \
  #   -CAfile certs/ca-bundle.crt

  # sleep 2
  # # Testing OCSP Stapling
  # echo | openssl s_client -connect $TARGET:443 -status

  sleep 2
  # Checking CRL Revocation
  uri=$(openssl x509 -in certs/site.crt -noout -text | grep crl | tr -d '[:space:]')
  curl -o certs/ca.crl $(echo $uri | sed 's/^URI:\(.*\)/\1/g')
  openssl crl -in certs/ca.crl -inform PEM -CAfile certs/ca-bundle.crt -noout
  serial=$(openssl x509 -in certs/site.crt -noout -serial | awk -F '=' '{print $2}')
  openssl crl -in certs/ca.crl -inform PEM -text -noout | grep $serial
  if [ $? -ne 0 ]; then
    echo "The certificate has not been revocated!"
  else
    echo "The certificate has been revocated!"
  fi

}

$1

# rm -rv certs; bash -x pki-test.sh setup
# bash -x pki-test.sh tests

