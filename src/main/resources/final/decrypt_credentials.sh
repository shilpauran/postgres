#!/bin/bash

echo "Decrypt *.enc files"
if [ -f "decrypt_password_in" ]; then
    # Read from a file so that the password is not maintained
    # in the users command history
    password=$(read line < decrypt_password_in && echo $line)
else
    echo -n "password:"
    read -s password
    echo
fi

if [ -z "$password" ]; then
    echo "Please provide a password"
    exit
fi

# Decrypt all files with .enc file endings
folder="$(pwd)/*.enc"
for f in $folder
do
    f=$(basename $f)
    fdec=$(basename $f .enc)
    if [ "$fdec" == "*" ]; then
        echo "No files to decrypt"
        exit 0
    fi
    if [[ $fdec == *.key ]]; then
        # Switching encryption method
        #   If file contains
        #       -----BEGIN RSA PRIVATE KEY-----
        #       Proc-Type: 4,ENCRYPTED
        #       DEK-Info: AES-256-CBC,82A25DC32C0AB0EF681570311057A5A9
        #   Then it was encrypted using openssl rsa
        #   If the file is a jumble of characters it was encrypted using aes-256-cbc
        #   This was done due to the key files not decrypting identically
        if cat $f | grep "BEGIN RSA PRIVATE KEY" > /dev/null; then
            echo "Decrypting rsa key to $fdec"
            openssl rsa -in "$f" -out "$fdec" -passin pass:$password
        else
            echo "Decrypting cbc key to $fdec"
            openssl aes-256-cbc -md md5 -d -in $f -out $fdec -a -k $password
        fi
    else
        echo "Decrypting file $f to $fdec"
        openssl aes-256-cbc -md md5 -d -in $f -out $fdec -a -k $password
    fi
done