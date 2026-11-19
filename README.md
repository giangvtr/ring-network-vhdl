# Ring Network VHDL

Réseau en anneau unidirectionnel en VHDL : N×N nœuds disposés sur le pourtour d'une grille, chaînés par un unique lien `TR_OUT → TR_IN`, chacun capable d'injecter, de recevoir et de relayer des messages.

**Auteurs :** Mathis & Giang

## Fonctionnement

Chaque nœud compare l'adresse de la trame entrante à sa propre adresse :
- adressée à lui : le message est délivré (`MESS_OUT`), le slot repart vide ;
- adressée ailleurs : la trame est relayée telle quelle (priorité absolue au transit) ;
- slot vide et message local en attente (`ENV_MESS`) : injection.

Un buffer TX 1 place retient le message en cas de collision injection et transmission, avec un handshake `BUSY` (contrat ready/valid : refusé tant que `BUSY='1'`, l'environnement doit réessayer). Pour éviter la famine d'un nœud en aval d'un trafic saturant, un bit de réservation de slot (inspiré IEEE 802.5) borne l'attente. 


## Architecture du nœud ([node.vhd](node.vhd))

```
TR_IN (9b) ──┬── adresse = moi ? ──► MESS_OUT
             │
             └── sinon → relayé → TR_OUT (9b)

ENV_MESS + MESS_IN ──► [buffer TX 1 place] ──► TR_OUT (si slot libre)
                              │
                              └──► BUSY (handshake ready/valid)
```

- **Entrées :** `CLK`, `TEST_IN`, `ENV_MESS`, `MESS_IN` (4b), `TR_IN` (9b)
- **Sorties :** `TEST_OK`, `BUSY`, `MESS_OUT` (4b), `TR_OUT` (9b)
- **Generics :** `adr_cur`, `adr_dest` (4b chacun), `STARVE_THRESH` (seuil anti-famine)
- Mode test (`TEST_IN`) : le nœud émet une trame à lui-même (code `x"C"`) pour vérifier l'intégrité de l'anneau (`TEST_OK` si elle revient intacte).

## Architecture réseau ([network.vhd](network.vhd))

Grille N×N, seuls les nœuds du pourtour sont instanciés (`4N-4` nœuds, bordure uniquement), reliés en anneau via `border_index`. Chaque nœud a une interface réseau complète (ports en tableaux `Test_in`, `Env_mes`, `Test_ok`, `Busy`, `Mess_in`, `Mess_out` indexés par position sur l'anneau). L'adresse de destination de chaque nœud est son symétrique diamétral (`ADDR_MAP`).

## Architecture de trame

```
 8     7 6 5 4   3 2 1 0
┌───┬───────────┬───────────┐
│rsv│  adresse  │  message  │
└───┴───────────┴───────────┘
```
- **resv** (bit 8) : marque un slot réservé par un nœud affamé (mécanisme anti-famine).
- **adresse** (4b) : destinataire ; `x"F"` = slot vide (encodage in-band du token libre/occupé).
- **message** (4b) : charge utile ; `x"C"` réservé au mode test.

## Vérification

Testbenches VHDL dirigés (`node_tb.vhd`, `network_tb.vhd`, via `run_node.do`/`run_full.do`) et suite cocotb (`tests/`, trafic aléatoire multi-nœuds avec scoreboard).
