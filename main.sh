#!/bin/bash

# bash -x main.sh root_ca
# bash -x main.sh signing_ca
# bash -x main.sh cert

conf_dir=etc

if [ -f $conf_dir/profile_site ]; then
  source $conf_dir/profile_site
else
  echo "Unable to find '$conf_dir/profile_site'"
  exit 1
fi

if [ -f $conf_dir/profile_ca ]; then
  source $conf_dir/profile_ca
else
  echo "Unable to find '$conf_dir/profile_ca'"
  exit 1
fi

export root_ca_dir=pki/root_ca
export signing_ca_dir=pki/signing_ca
export ssh_user_keypair_dir=pki/users
export site_dir=pki/sites/"$SITE_CN"_$(date +"%Y%m%d%H%M%S")

echo "#########################################################"
echo

function check_and_install {
  if dpkg -s $1 &> /dev/null; then
    echo "$1 is already installed."
  else
    sudo apt install -y $1
  fi
}

check_and_install apache2
check_and_install tree

function get_ca_home {
  if [ $1 == "root_ca" ]; then
    echo $root_ca_dir
  elif [ $1 == "signing_ca" ]; then
    echo $signing_ca_dir
  else
    echo "Invalid option entered"
    exit 1
  fi
}

function print_crl {
  # print_crl root_ca
  ca_home=$(get_ca_home $1)
  cat $ca_home/db/index
  openssl crl \
    -text \
    -noout \
    -in $ca_home/ca.crl
  echo "#########################################################"
}

function revoke {
  # revoke root_ca
  # revoke signing_ca

  ca_home=$(get_ca_home $1)
  if [[ $? -ne 0 ]]; then exit 1; fi

  echo -e "Status\tExpir\t\tRevoc\tSerial\t\t\t\t\tString\tDN"
  cat $ca_home/db/index
  echo
  echo "Please enter the serial number of the certificate \
you want to revoke."
  read serial_number
  echo "Please select one of the reasons below to revoke \
this certificate."
  cat << EOF
  unspecified
  keyCompromise
  CACompromise
  affiliationChanged
  superseded
  cessationOfOperation
  certificateHold
  removeFromCRL
  /* Additional pseudo reasons */
  holdInstruction
  keyTime
  CAkeyTime
EOF
  # https://github.com/openssl/openssl/blob/master/apps/ca.c#L2243
  read reason

  openssl ca \
    -passin file:$ca_home/pp/ca_passphrase.txt \
    -config $conf_dir/$1.conf \
    -revoke $ca_home/certs/"$serial_number".pem \
    -crl_reason "$reason"

  openssl ca \
    -gencrl \
    -passin file:$ca_home/pp/ca_passphrase.txt \
    -config $conf_dir/$1.conf \
    -out $ca_home/ca.crl

  echo "Re-deploy CRL"

  cp -v $ca_home/ca.crl pki/sites/"$SITE_CN"/$1.crl

  print_crl $1

  if [[ $1 == signing_ca ]]
  then
    site_cn=`cat $ca_home/db/index | \
      grep $serial_number | \
      awk '{print $NF}' | \
      awk -F '/' '{print $5}' | \
      awk -F '=' '{print $2}'`

    find pki/sites -type l -name "$site_cn.tar.gz" -exec bash -cx "rm -v {}" \;
  fi

  echo "#########################################################"
}

function root_ca {

  case $1 in
    create)
      # to struct root ca directory
      mkdir -p $root_ca_dir/{certs,db,private,pp,archive}
      chmod -v 700 $root_ca_dir/private
      touch $root_ca_dir/db/index
      touch $root_ca_dir/db/index.attr
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
        -config $conf_dir/root_ca.conf \
        -out $root_ca_dir/ca.csr \
        -keyout $root_ca_dir/private/ca.key

      openssl ca \
        -selfsign \
        -passin file:$root_ca_dir/pp/ca_passphrase.txt \
        -config $conf_dir/root_ca.conf \
        -in $root_ca_dir/ca.csr \
        -out $root_ca_dir/ca.crt \
        -extensions ca_ext \
        -batch

      # to list the db file
      cat $root_ca_dir/db/index

      # to generate a crl for the new ca
      openssl ca \
        -gencrl \
        -passin file:$root_ca_dir/pp/ca_passphrase.txt \
        -config $conf_dir/root_ca.conf \
        -out $root_ca_dir/ca.crl

      chmod -v 640 $root_ca_dir/pp/*
      chmod -v 640 $root_ca_dir/private/*

      tar zcvf $root_ca_dir/archive/$(date +"%Y%m%d%H%M%S")_root_ca.tar.gz \
        $conf_dir/profile_ca \
        $conf_dir/root_ca.conf \
        $root_ca_dir/pp/ca_passphrase.txt \
        $root_ca_dir/ca.csr \
        $root_ca_dir/private/ca.key \
        $root_ca_dir/ca.crt

      echo "Deploy to site_dir"
      [ -d $site_dir ] || mkdir -p $site_dir

      # cp -v $root_ca_dir/ca.crt $site_dir/root_ca.crt
      cp -v $root_ca_dir/ca.crl pki/sites/root_ca.crl

      tree $root_ca_dir
      ;;
    *)
      echo "Invalid option entered"
      exit 1
      ;;
  esac

echo "#########################################################"
}

function root_ca_ocsp {
  case $1 in
    issue)
      # to create a passphrase for the private key of ocsp
      openssl rand \
        -base64 48 \
        > $root_ca_dir/pp/ocsp_passphrase.txt

      openssl req \
        -new \
        -passout file:$root_ca_dir/pp/ocsp_passphrase.txt \
        -config $conf_dir/root_ca_ocsp.conf \
        -keyout $root_ca_dir/private/ocsp_encrypted.key \
        -out $root_ca_dir/ocsp.csr

      # It's because ocsp command doesn't provide 'passin' option.
      openssl rsa \
        -passin file:$root_ca_dir/pp/ocsp_passphrase.txt \
        -in $root_ca_dir/private/ocsp_encrypted.key \
        -out $root_ca_dir/private/ocsp.key

      openssl ca \
        -passin file:$root_ca_dir/pp/ca_passphrase.txt \
        -config $conf_dir/root_ca.conf \
        -in $root_ca_dir/ocsp.csr \
        -out $root_ca_dir/ocsp.crt \
        -extensions ocsp_ext \
        -days 30 \
        -batch

      # to list the db file
      cat $root_ca_dir/db/index

      chmod -v 640 $root_ca_dir/pp/*
      chmod -v 640 $root_ca_dir/private/*

      tar zcvf $root_ca_dir/archive/$(date +"%Y%m%d%H%M%S")_root_ca_ocsp.tar.gz \
        $conf_dir/profile_ca \
        $conf_dir/root_ca.conf \
        $conf_dir/root_ca_ocsp.conf \
        $root_ca_dir/pp/ocsp_passphrase.txt \
        $root_ca_dir/ocsp.csr \
        $root_ca_dir/private/ocsp.key \
        $root_ca_dir/ocsp.crt

      tree $root_ca_dir
      ;;
    *)
      echo "Invalid option entered"
      exit 1
      ;;
  esac

  echo "#########################################################"
}

function signing_ca {

  case $1 in
    create)
      # to struct signing ca directory
      mkdir -p $signing_ca_dir/{certs,db,private,pp,archive}
      chmod -v 700 $signing_ca_dir/private
      touch $signing_ca_dir/db/index
      touch $signing_ca_dir/db/index.attr
      openssl rand -hex 16 > $signing_ca_dir/db/serial
      echo 1001 > $signing_ca_dir/db/crlnumber

      # to create a passphrase for the private key of sub ca
      openssl rand \
        -base64 48 \
        > $signing_ca_dir/pp/ca_passphrase.txt

      # to create subordinate ca
      openssl req \
        -new \
        -passout file:$signing_ca_dir/pp/ca_passphrase.txt \
        -config $conf_dir/signing_ca.conf \
        -out $signing_ca_dir/ca.csr \
        -keyout $signing_ca_dir/private/ca.key

      openssl rsa \
        -passin file:$signing_ca_dir/pp/ca_passphrase.txt \
        -in $signing_ca_dir/private/ca.key \
        -out $signing_ca_dir/private/ca_decrypted.key

      openssl rsa \
        -in $signing_ca_dir/private/ca_decrypted.key \
        -pubout \
        -out $signing_ca_dir/ca.pub

      openssl ca \
        -config $conf_dir/root_ca.conf \
        -passin file:$root_ca_dir/pp/ca_passphrase.txt \
        -in $signing_ca_dir/ca.csr \
        -out $signing_ca_dir/ca.crt \
        -batch \
        -extensions signing_ca_ext

      # to list the db file
      cat $root_ca_dir/db/index
      cat $signing_ca_dir/db/index

      # to generate a crl for the new ca
      openssl ca \
        -gencrl \
        -passin file:$signing_ca_dir/pp/ca_passphrase.txt \
        -config $conf_dir/signing_ca.conf \
        -out $signing_ca_dir/ca.crl

      tar zcvf $signing_ca_dir/archive/$(date +"%Y%m%d%H%M%S")_signing_ca.tar.gz \
        $conf_dir/profile_ca \
        $conf_dir/signing_ca.conf \
        $conf_dir/root_ca.conf \
        $signing_ca_dir/pp/ca_passphrase.txt \
        $signing_ca_dir/ca.csr \
        $signing_ca_dir/private/ca.key \
        $signing_ca_dir/ca.crt

      cat $signing_ca_dir/ca.crt $root_ca_dir/ca.crt | tee \
        $signing_ca_dir/ca-bundle.crt

      echo "Deploy to site_dir"
      [ -d $site_dir ] || mkdir -p $site_dir

      # cp -v $signing_ca_dir/ca.crt $site_dir/signing_ca.crt
      cp -v $signing_ca_dir/ca.crl pki/sites/signing_ca.crl
      cp -v $signing_ca_dir/ca-bundle.crt pki/sites/ca-bundle.crt

      tree $signing_ca_dir
      ;;
    *)
      echo "Invalid option entered"
      exit 1
      ;;
  esac

  echo "#########################################################"
}

function signing_ca_ocsp {
  case $1 in
    issue)
      # to create a passphrase for the private key of ocsp
      openssl rand \
        -base64 48 \
        > $signing_ca_dir/pp/ocsp_passphrase.txt

      openssl req \
        -new \
        -passout file:$signing_ca_dir/pp/ocsp_passphrase.txt \
        -config $conf_dir/signing_ca_ocsp.conf \
        -keyout $signing_ca_dir/private/ocsp_encrypted.key \
        -out $signing_ca_dir/ocsp.csr

      openssl rsa \
        -passin file:$signing_ca_dir/pp/ocsp_passphrase.txt \
        -in $signing_ca_dir/private/ocsp_encrypted.key \
        -out $signing_ca_dir/private/ocsp.key

      openssl ca \
        -passin file:$signing_ca_dir/pp/ca_passphrase.txt \
        -config $conf_dir/signing_ca.conf \
        -in $signing_ca_dir/ocsp.csr \
        -out $signing_ca_dir/ocsp.crt \
        -extensions ocsp_ext \
        -days 30 \
        -batch

      # to list the db file
      cat $signing_ca_dir/db/index

      chmod -v 640 $signing_ca_dir/pp/*
      chmod -v 640 $signing_ca_dir/private/*
      chmod -v 600 $signing_ca_dir/private/*_decrypted.key

      tar zcvf $signing_ca_dir/archive/$(date +"%Y%m%d%H%M%S")_signing_ca_ocsp.tar.gz \
        $conf_dir/profile_ca \
        $conf_dir/signing_ca.conf \
        $conf_dir/signing_ca_ocsp.conf \
        $signing_ca_dir/pp/ocsp_passphrase.txt \
        $signing_ca_dir/ocsp.csr \
        $signing_ca_dir/private/ocsp.key \
        $signing_ca_dir/ocsp.crt

      tree $signing_ca_dir
      ;;
    *)
      echo "Invalid option entered"
      exit 1
      ;;
  esac

  echo "#########################################################"
}

function site {

  # check if creating a new site certificate
  if [ ! -z "$2" ]; then

    new_site_conf=profile_site_$2

    # check if there is the new profile
    if [ -f $conf_dir/$new_site_conf ]; then
      source $conf_dir/$new_site_conf
      export site_dir=pki/sites/"$SITE_CN"_$(date +"%Y%m%d%H%M%S")
    else
      echo "Unable to find '$conf_dir/$new_site_conf'"
      exit 1
    fi

  fi

  for FILE in `find pki/sites -maxdepth 1 -type l -print`
  do
    if [[ $(basename $FILE) == $SITE_CN ]]
    then
      echo "The certificate for the site '$SITE_CN' has been issued already."
      exit 1
    fi
  done

  [ -d $site_dir ] || mkdir -p $site_dir

  case $1 in
    issue)
      # signing ca operations
      openssl rand \
        -base64 48 \
        > $site_dir/"$SITE_CN"_pp.txt

      openssl req \
        -new \
        -passout file:$site_dir/"$SITE_CN"_pp.txt \
        -keyout $site_dir/$SITE_CN.key \
        -config $conf_dir/site.conf \
        -out $site_dir/$SITE_CN.csr

      openssl rsa \
        -passin file:$site_dir/"$SITE_CN"_pp.txt \
        -in $site_dir/$SITE_CN.key \
        -out $site_dir/"$SITE_CN"_decrypted.key

      openssl ca \
        -config $conf_dir/signing_ca.conf \
        -batch \
        -passin file:$signing_ca_dir/pp/ca_passphrase.txt \
        -in $site_dir/$SITE_CN.csr \
        -out $site_dir/$SITE_CN.crt \
        -extensions server_ext

      # to generate a crl for the new ca
      openssl ca \
        -gencrl \
        -passin file:$signing_ca_dir/pp/ca_passphrase.txt \
        -config $conf_dir/signing_ca.conf \
        -out $signing_ca_dir/ca.crl

      # to list the db file
      cat $signing_ca_dir/db/index

      serial_number=`cat $signing_ca_dir/db/index | \
        egrep '^V' |
        grep $SITE_CN | \
        awk '{print $3}'`

      # chmod -v 640 $signing_ca_dir/pp/*
      # chmod -v 640 $signing_ca_dir/private/*
      # chmod -v 600 $signing_ca_dir/private/*_decrypted.key

      cp -v pki/sites/ca-bundle.crt $site_dir/

      # archiving for users
      tar zcvf $signing_ca_dir/archive/"$(basename $site_dir)"_"$serial_number".tar.gz \
        -C $site_dir \
        ca-bundle.crt \
        "$SITE_CN"_pp.txt \
        $SITE_CN.key \
        "$SITE_CN"_decrypted.key \
        $SITE_CN.crt

      cp -v $conf_dir/profile_ca $site_dir/
      cp -v $conf_dir/profile_site $site_dir/
      cp -v $conf_dir/signing_ca.conf $site_dir/

      # archiving for PKI admin
      tar zcvf $signing_ca_dir/archive/"$(basename $site_dir)"_"$serial_number"_admin.tar.gz \
        -C $site_dir \
        ca-bundle.crt \
        profile_ca \
        profile_site \
        signing_ca.conf \
        "$SITE_CN"_pp.txt \
        $SITE_CN.key \
        "$SITE_CN"_decrypted.key \
        $SITE_CN.crt
        $SITE_CN.csr \

      echo "Deploy to site_dir"

      rm -rv $site_dir

      ln -fns "$PWD"/"$signing_ca_dir"/archive/"$(basename $site_dir)"_"$serial_number".tar.gz \
        pki/sites/"$SITE_CN".tar.gz

      # ln -fns "$PWD"/"$site_dir" "$PWD"/pki/sites/"$SITE_CN"

      tree pki/sites
      ;;
    *)
      echo "Invalid option entered"
      exit 1
      ;;
  esac

  echo "#########################################################"
}

function ssh_keypair {
  # ssh_keypair revoke ubuntu
  username=$2
  EXPIRATION=52w

  case $1 in
    issue)

      if [ -d $ssh_user_keypair_dir ]; then

        for FILE in `find $ssh_user_keypair_dir -maxdepth 1 -type l -print`
        do
          if [[ $(basename $FILE) == $username ]]
          then
            echo "The keypair for the user '$username' has been issued already."
            exit 1
          fi
        done

      else
        mkdir -p $ssh_user_keypair_dir
      fi

      if find $ssh_user_keypair_dir -type l -name "$username*" | egrep '.*'; then
        echo "$username's key pair has not been revoked yet. Please revoke it first."
        return 9
      fi

      dir_name="$username"_"$(date +"%Y%m%d%H%M%S")"
      mkdir -p "$ssh_user_keypair_dir"/"$dir_name"

      # to create ssh key pair for a new user
      # this will generate $username_id_rsa and $username_id_rsa.pub
      ssh-keygen \
        -t rsa \
        -b 2048 \
        -f "$ssh_user_keypair_dir"/"$dir_name"/"$username"_id_rsa \
        -C noname \
        -N ''

      # to sign user key pair with ca signing certificate
      # this will generate $username_id_rsa-cert.pub
      # $username_id_rsa-cert.pub has to be in the directory as $username_id_rsa and 
      # will be used being sent over after sending $username_id_rsa
      ssh-keygen \
        -s $signing_ca_dir/private/ca_decrypted.key \
        -I user_$username \
        -n $username \
        -V +$EXPIRATION \
        "$ssh_user_keypair_dir"/"$dir_name"/"$username"_id_rsa.pub

      # create symbolic links
      # for keypair in `ls "$PWD"/"$ssh_user_keypair_dir"/"$dir_name"`; do
      #   ln -fns "$PWD"/"$ssh_user_keypair_dir"/"$dir_name"/"$keypair" \
      #     "$PWD"/"$ssh_user_keypair_dir"/"$keypair"
      # done
      ln -fns $PWD/$ssh_user_keypair_dir/$dir_name \
        $PWD/$ssh_user_keypair_dir/$username

      # copy public key of ca signing certificate to be used for sshd_config
      if [ ! -f $ssh_user_keypair_dir/ssh_ca.pub ]; then
        ssh-keygen -f $signing_ca_dir/ca.pub -i -mPKCS8 > $ssh_user_keypair_dir/ssh_ca.pub
      fi

      tar zcvf $ssh_user_keypair_dir/$dir_name.tar.gz -C $ssh_user_keypair_dir/$dir_name .

      ln -fns $PWD/$ssh_user_keypair_dir/$dir_name.tar.gz \
        $PWD/$ssh_user_keypair_dir/$username.tar.gz

      tree $ssh_user_keypair_dir
      ;;
    revoke)
      if [ -f $ssh_user_keypair_dir/ssh-revoked-keys ]; then
        flag="-u"
      fi

      ssh-keygen \
        -k \
        -f $ssh_user_keypair_dir/ssh-revoked-keys \
        $flag \
        -s $ssh_user_keypair_dir/ssh_ca.pub \
        $ssh_user_keypair_dir/$username/"$username"_id_rsa.pub

      find $ssh_user_keypair_dir -type l -name "$username*" -exec bash -cx "rm -v {}" \;

      tree $ssh_user_keypair_dir
      ;;
    *)
      echo "Invalid option entered"
      exit 1
      ;;
  esac

  echo "#########################################################"
}

function deploy_ca_certs_locally {

  #sudo rm /usr/local/share/ca-certificates/$ROOT_CA_O.crt
  sudo update-ca-certificates --fresh

  # sudo cp -v $site_dir/ca-bundle.crt \
  #   /usr/local/share/ca-certificates/$ROOT_CA_O.crt
  # sudo update-ca-certificates

  echo "#########################################################"
}

function restart_ocsp_responder {

  sudo netstat -ntlp | \
    grep 9080 | \
    awk '{print $7}' | \
    awk -F '/' '{print $1}' | \
    xargs kill

  sleep 0.5
  sudo netstat -ntlp
  sleep 0.5

  # for this, you have to enter passphrase manually
  openssl ocsp \
   -port 9080 \
   -index $root_ca_dir/db/index \
   -rsigner $root_ca_dir/ocsp.crt \
   -rkey $root_ca_dir/private/ocsp.key \
   -CA $root_ca_dir/ca.crt \
   -text &

  echo
  sleep 0.5

  sudo netstat -ntlp | \
    grep 9081 | \
    awk '{print $7}' | \
    awk -F '/' '{print $1}' | \
    xargs kill

  sleep 0.5
  sudo netstat -ntlp

  # for this, you have to enter passphrase manually
  openssl ocsp \
   -port 9081 \
   -index $signing_ca_dir/db/index \
   -rsigner $signing_ca_dir/ocsp.crt \
   -rkey $signing_ca_dir/private/ocsp.key \
   -CA $signing_ca_dir/ca.crt \
   -text &

  echo
  sudo apachectl restart

  echo "#########################################################"
}


function restart_apache {

  sudo ln -fns $PWD/pki/sites /var/www/html/sites
  sudo ln -fns $PWD/pki/users /var/www/html/users

  sudo bash -c 'cat << EOF > /etc/apache2/sites-enabled/000-default.conf
<VirtualHost *:80>

  ServerName pki.origin.don
  ServerAdmin webmaster@localhost
  DocumentRoot /var/www/html

  ErrorLog \${APACHE_LOG_DIR}/error.log
  CustomLog \${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
EOF'

#   cat << EOF > pki/sites/apache.conf
# <IfModule mod_ssl.c>
# 	<VirtualHost _default_:443>
# 		ServerAdmin webmaster@localhost
# 
# 		DocumentRoot /var/www/html
# 
# 		ErrorLog \${APACHE_LOG_DIR}/error.log
# 		CustomLog \${APACHE_LOG_DIR}/access.log combined
# 
# 		SSLEngine on
# 
#     SSLCertificateFile	$PWD/$site_dir/$(echo $SITE_CN)_$(date +%Y).crt
#     SSLCertificateKeyFile $PWD/$site_dir/$(echo $SITE_CN)_$(date +%Y)_decrypted.key
# 		SSLCertificateChainFile $PWD/$site_dir/signing_ca.crt
# 
# 		<FilesMatch "\.(cgi|shtml|phtml|php)$">
# 				SSLOptions +StdEnvVars
# 		</FilesMatch>
# 		<Directory /usr/lib/cgi-bin>
# 				SSLOptions +StdEnvVars
# 		</Directory>
# 
# 	</VirtualHost>
# </IfModule>
# EOF

  cat /etc/apache2/sites-enabled/000-default.conf
  sudo apachectl restart

  echo "#########################################################"
}

function restart_apache_with_ocsp_stapling {
  cat << EOF > $site_dir/apache.conf
<IfModule mod_ssl.c>
  SSLStaplingCache shmcb:/tmp/stapling_cache(128000)
	<VirtualHost _default_:443>
		ServerAdmin webmaster@localhost

		DocumentRoot /var/www/html

		ErrorLog \${APACHE_LOG_DIR}/error.log
		CustomLog \${APACHE_LOG_DIR}/access.log combined

		SSLEngine on

    SSLCertificateFile	$PWD/$site_dir/cert.crt
    SSLCertificateKeyFile $PWD/$site_dir/cert_decrypted.key
		SSLCertificateChainFile $PWD/$site_dir/signing_ca.crt
		SSLUseStapling on

		<FilesMatch "\.(cgi|shtml|phtml|php)$">
				SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
				SSLOptions +StdEnvVars
		</Directory>

	</VirtualHost>
</IfModule>
EOF

  cat $site_dir/apache.conf
  sudo rm -v /etc/apache2/sites-enabled/pki.conf
  sudo ln -fns $PWD/$site_dir/apache.conf \
    /etc/apache2/sites-enabled/pki.conf
  sudo apachectl restart

  echo "#########################################################"
}



function quick_start {

  root_ca create
  root_ca_ocsp issue
  signing_ca create
  signing_ca_ocsp issue
  site issue
  ssh_keypair issue ubuntu
  deploy_ca_certs_locally
  # #restart_ocsp_responder
  # #restart_apache_with_ocsp_stapling
  restart_apache

  echo "#########################################################"
}

$1 $2 $3

