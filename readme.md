# Automated Rails Deployment With Vagrant

# 1.Namen projekta

Cilj je bil da pokažemo kako lahko spletno aplikacijo deployamo varno,večktrat z uporabo samo enega ukaza na MAC-OS.
Za virtualko uporabimo Ubuntu 24.04 box in provision skripte ki:
  - inštalira in konfigurira vsak servis, ki ga aplikacija potrebuje (PostgreSQL,Redis,Ruby,Puma,nginx)
  - inštalira celoten monitoring in logging stack
  - verificira da vse dela z avtomatiziranim "smoke test"
  - uporabi različne varnostne mehanizme (HTTPS,protekcije pred brute force,firewall,SSH)
  - celotna aplikacija se lahko izbriše/ustavi in ponovno zgradi in skripte so varne da jih ponovno zaženemo ter je vgrajena trajnost(podatki shranijo ob ponovnem zagonu - samo brez --provision)


# 2.Dodatne funkcionalnosti (bolj podbrobno)

## Avtomatzacija

  - oštevilčene modularne provizije 00-99,vsak lahko zaženemo posebej z vagrant provision --provision-with <ime>
  - ponovni zagon skript ne duplicira konfiguracije ali regenerira obstoječe skrivnosti/ključe
  - vgrajen smoke-test ki pregleda in testira provisioing in če je kaj narobe potem pade
  - avtomatski sidekiq detekcija: če gemfile vsebuje sidekiq,"worker service" se kreira

## Varnost

  - **Varnost** Netwowrk: UFW firewall blokira ves vhodni promet razen na vratih 22,80,443,baze in monitoring servisi poslušajo samo na localhost,fail2ban za SSH in nginx basic-auth
  - **SSH**: root login disabled,max 4 poskusi,avtentikacijo samo z ključem
  - **Brute force zaščita**:
  - **Skrivnosti**: naključno generirane na okolje;nikoli "hardcoded"(Bza,Redis,SECRET_KEY_BASE in admin gesla),shranjeni v /etc/myapp z omejenimi pravicami(root:deploy 640 env file,root 600 credentials file)
  - **TLS**:  ves zunanji promet iz HTTPS;HTTP preusmeri na HTTPS,2 načina mkcert(lokalno zaupan CA za development) in letsencrypt(pravi certifikati prek Cloudflare DNS challenge z auto-renewa- hook)
  - **Kernel**: SYN cookies,reverse-path filterting in ICMP redirect protekcija prek sysctl
## Monitoring and Logging

  - Centraliziran logging z Loki in Grafana Alloy(journal in log shipping)
  - Prometheus z node,PostgreSQL,redis in nginx exporterji
  - Persisent journald z storage size cap
  - Grafana z "data sources" in 3 community dashboards, ki so avtomatsko provizionirani
  - 

## Backups

  - Vsakodnevni pg_dump prek systemd timer,7 dnevnno zadržanje,en varnostna kopija ustvarjena ob provisionu

## Prilagajanje virov

  - Redis memory cap in lru policy,Puma workers/threads konfigurirane prek env

## Testing

  **99-smoketest.sh provisioner teče avtomatsko in preveri**:
  - če so vsi od 13 servisev aktivnih
  - Grafana health prek nginx
  - PostgreSQL query in Redis overjen PING
  - HTTPS app(/up) in HTTP -> HTTPS redirect
  - firewall je aktiven in varnostna kopija db obstaja
  - Prometheus potrebuje avtentikacijo in delo z njo
  - all Prometheus targets up

# 3.Potrebe

  - macOS
  - Vagrant z Vagrant VMWare utiliy(lahko uporabite virtualbox samo morate spremeniti vagrant file in ponovno zagnati)
  - VMWare Fusion/Virtual box
  - Vagrant in vagrant plugins(vagrant plugin install vagrant-vmware-desktop)
  - Dostop do interneta na prvem zagonu ter še dovolj CPU in RAM.

# 4.Vagrant Setup

## Git clone

```bash

git clone <https://github.com/aneltoric123/sk-44-virtualization>

cd vagrant  
vagrant up --provision
```

## Sprva vam ne bo delalo in bo trajalo kar precej časa za zagon,dokler ne spremenite /etc/hosts in dodate kar vam piše v zadnji vrstici ukaza.

## Zaupamo certifikatom (da pokaže validen "lock" in morate ponovni zagnati browser)
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ./certs/rootCA.pem
```
## Gremo na spletno stran

greste na spletno stran **https://myapp.local/**

## Ostale Vagrant komande

- ```bash vagrant halt ```(ustvai VM)
- ```bash vagrant up ```(zažene Vm brez provisioning razen pri prvem zagonu)
- vagrant ssh (SSH od VM)
- ```bash vagrant reload ```(ekvivalent če kličemo vagrant halt potem vagrant up,provisinioning ne bo ponovno zagnan,zato moramo uporabiti --provision)
- ```bash vagrant up --provision ```(zažene vse provisionarje)
- ```bash vagrant destroy -f ```(Izbriše vagrant)

# VAGRANT SLIKE IN POSNETKI