# Automated Rails Deployment With Vagrant

# 1.Namen projekta

Cilj je bil da pokažemo kako lahko spletno aplikacijo deployamo varno,večktrat in opazno brez ročnega strežnika.

# 4.Vagrant Setup

## Git clone

git clone <https://github.com/aneltoric123/sk-44-virtualization>

## **OBVEZNO DODATE**  to vrstico v /etc/hosts drugače ne bo delalo

172.16.21.10 myapp.local

##  Žaženite nasedlnji komandi za zagon

cd vagrant  
vagrant up 

## Zaupamo certifikatom (da pokaže validen "lock" in morate ponovni zagnati browser)
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ./certs/rootCA.pem

## Gremo na spletno stran
greste na spletno stran **https://myapp.local/**

# VAGRANT FUNKCIONALNOSTI

# VAGRANT SLIKE IN POSNETKI