#!/usr/bin/env zsh

# Base on https://help.ubuntu.com/community/OpenSSL


# ==============================================================================
# = Preamble                                                                   =
# ==============================================================================

setopt err_exit
source $0:h/library.zsh

cnf_dir=$CITYSDK_CONFIG_DIR
ssl=$repo/local/ssl


# ==============================================================================
# = Set up                                                                     =
# ==============================================================================

# Remove old certificates
rm --force --recursive $ssl

# Create and change a working directory for SSL certificates.
mkdir --parents $ssl/{signedcerts,private}

# Initialise the certificate database.
cd $ssl
print -- 01 > serial
touch index.txt


# ==============================================================================
# = CA certificate                                                             =
# ==============================================================================

export OPENSSL_CONF=$cnf_dir/caconfig.cnf

# Create a CA certificate.
openssl req -x509            \
            -newkey rsa:2048 \
            -out cacert.pem  \
            -outform PEM     \
            -days 1825

# Remove the unnecessary text.
openssl x509 -in cacert.pem -out cacert.crt


# ==============================================================================
# = Server certificates                                                        =
# ==============================================================================

function make_server_certificate()
{
    local common_name=$1
    local cnf=$cnf_dir/$common_name.cnf
    local crt=$common_name.crt
    local key=$common_name.key

    export OPENSSL_CONF=$cnf

    # Generate the server certificate and key.
    openssl req -newkey rsa:1024    \
                -keyout tempkey.pem \
                -keyform PEM        \
                -out tempreq.pem    \
                -outform PEM

    # Decrypt the server key.
    openssl rsa < tempkey.pem > $key

    export OPENSSL_CONF=$cnf_dir/caconfig.cnf

    # Sign the server's certificate.
    openssl ca -in tempreq.pem -out $crt

    # Remove temporary files.
    rm tempkey.pem tempreq.pem
}

server_name=$(config-setup server.domain_name)
make_server_certificate $server_name
make_server_certificate cms.$server_name

