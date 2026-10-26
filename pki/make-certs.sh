#!/usr/bin/env bash
# Create a private CA and a server certificate for the OwnTracks broker.
#
# The CA carries a critical name constraint limiting it to the server IP, so a
# phone that trusts it cannot be fooled into trusting certificates for other
# hosts, even if the CA key leaks. The CA private key is encrypted with a
# passphrase and never leaves this machine.
#
# Usage: pki/make-certs.sh <server-ip>
# Output: pki/out/  (gitignored)
set -euo pipefail

ip="${1:?usage: make-certs.sh <server-ip>}"
[[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "Not an IPv4 address: $ip"; exit 1; }

out="$(dirname "$0")/out"
mkdir -p "$out"
chmod 700 "$out"
cd "$out"
umask 077

ca_days=3650
srv_days=825   # iOS rejects TLS server certificates valid longer than 825 days

if [[ ! -f ca.key ]]; then
  read -rsp "Passphrase for the CA private key (Proton Pass item: 'OwnTracks CA key'): " CA_PASS; echo
  read -rsp "Same passphrase again to confirm: " CA_PASS2; echo
  [[ "$CA_PASS" == "$CA_PASS2" ]] || { echo "Passphrases do not match."; exit 1; }
  unset CA_PASS2
  export CA_PASS

  cat > ca.cnf <<CNF
[req]
distinguished_name = dn
prompt             = no
x509_extensions    = v3_ca
[dn]
CN = OwnTracks Private CA
[v3_ca]
basicConstraints       = critical, CA:TRUE, pathlen:0
keyUsage               = critical, keyCertSign, cRLSign
subjectKeyIdentifier   = hash
nameConstraints        = critical, permitted;IP:${ip}/255.255.255.255
CNF

  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
    -aes-256-cbc -pass env:CA_PASS -out ca.key
  openssl req -new -x509 -key ca.key -passin env:CA_PASS \
    -config ca.cnf -days "$ca_days" -sha256 -out ca.crt
  echo "Created CA: $out/ca.crt"
else
  read -rsp "Passphrase for the CA private key (Proton Pass item: 'OwnTracks CA key'): " CA_PASS; echo
  export CA_PASS
fi

cat > server.cnf <<CNF
[req]
distinguished_name = dn
prompt             = no
[dn]
CN = ${ip}
[v3_srv]
basicConstraints       = critical, CA:FALSE
keyUsage               = critical, digitalSignature
extendedKeyUsage       = serverAuth
subjectAltName         = IP:${ip}
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid
CNF

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out server.key
openssl req -new -key server.key -config server.cnf -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -passin env:CA_PASS \
  -CAcreateserial -days "$srv_days" -sha256 \
  -extfile server.cnf -extensions v3_srv -out server.crt
unset CA_PASS
rm -f server.csr

# DER copy for phones that import .cer/.der
openssl x509 -in ca.crt -outform der -out ca.cer

openssl verify -CAfile ca.crt server.crt
echo
openssl x509 -in server.crt -noout -subject -enddate -ext subjectAltName
echo
echo "Files in $out:"
ls -l
