"""Network-level tests (N=3, 8 noeuds): trafic aleatoire + scoreboard, saturation/equite.

Contrat d'injection (handshake BUSY): un message presente (ENV_MESS=1) pendant un
cycle ou BUSY=0 est accepte au front suivant; pendant BUSY=1 il est refuse et
l'environnement le represente.

Convention de phase: les entrees sont ecrites juste apres le front montant;
les sorties (registres, stables tout le cycle) sont lues au front descendant.
"""

import random
from collections import Counter

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

NB = 8
# adresse de chaque noeud (indice anneau, cf. ADDR_MAP/border_index dans network.vhd)
ADDR = [0x0, 0x1, 0x3, 0x4, 0x5, 0x6, 0xB, 0xC]
# chaque noeud envoie vers le coin oppose = noeud diametralement oppose sur l'anneau
DEST_IDX = [(i + 4) % NB for i in range(NB)]
# valeurs de message observables: pas 0 (indistinguable du repos), pas 0xC (code test)
MSG_VALUES = [v for v in range(1, 16) if v != 0xC]
STARVE_THRESH = 16


async def setup(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.test_in.value = 0
    dut.env_mes.value = 0
    dut.mess_in_flat.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)


async def run_traffic(dut, to_send, max_cycles, rate=0.5, rng=None):
    """Fait envoyer a chaque noeud i la liste to_send[i] (valeurs de message),
    en respectant le handshake BUSY. Retourne (recu, latences, livraisons) ou
    recu[i] est le multiset des messages observes sur Mess_out(i), latences la
    liste des (noeud source, cycles entre acceptation et livraison), et
    livraisons la liste des (noeud source, cycle de livraison) — de quoi
    calculer un debit par noeud."""
    rng = rng or random.Random(0)
    pending = [list(msgs) for msgs in to_send]   # messages restant a presenter
    presenting = [None] * NB                     # message actuellement presente
    inflight = [[] for _ in range(NB)]           # par noeud source: (valeur, cycle d'acceptation)
    recu = [Counter() for _ in range(NB)]
    latences = []
    livraisons = []                              # (noeud source, cycle de livraison)
    total = sum(len(m) for m in to_send)
    delivered = 0
    prev_busy = [0] * NB
    drain = None

    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)

        # acceptation au front qui vient d'avoir lieu: presente + BUSY=0 pendant le cycle ecoule
        for i in range(NB):
            if presenting[i] is not None and prev_busy[i] == 0:
                inflight[i].append((presenting[i], cycle))
                presenting[i] = None

        # presenter / maintenir les messages pour le cycle qui commence
        # (vecteurs declares (0 to ...): l'indice 0 est le bit/nibble de poids fort)
        env = 0
        flat = 0
        for i in range(NB):
            if presenting[i] is None and pending[i] and rng.random() < rate:
                presenting[i] = pending[i].pop(0)
            if presenting[i] is not None:
                env |= 1 << (NB - 1 - i)
                flat |= presenting[i] << (4 * (NB - 1 - i))
        dut.env_mes.value = env
        dut.mess_in_flat.value = flat

        await FallingEdge(dut.clk)

        # livraison: Mess_out(i) != 0 pendant exactement 1 cycle
        mo = dut.mess_out_flat.value.to_unsigned()
        for i in range(NB):
            v = (mo >> (4 * (NB - 1 - i))) & 0xF
            if v != 0:
                recu[i][v] += 1
                delivered += 1
                src = (i + 4) % NB  # l'expediteur dont i est la destination
                livraisons.append((src, cycle))
                for k, (val, t0) in enumerate(inflight[src]):
                    if val == v:
                        latences.append((src, cycle - t0))
                        del inflight[src][k]
                        break

        b = dut.busy.value.to_unsigned()
        prev_busy = [(b >> (NB - 1 - i)) & 1 for i in range(NB)]

        # tout envoye et tout livre: encore quelques cycles de drainage puis sortie
        if drain is None and delivered == total:
            drain = cycle + 3 * NB
        if drain is not None and cycle >= drain:
            break

    dut.env_mes.value = 0
    return recu, latences, livraisons


def debit_par_noeud(livraisons, noeuds):
    """Debit (messages/cycle) de chaque noeud sur sa fenetre active
    [premiere livraison, derniere livraison]."""
    debits = {}
    for n in noeuds:
        cycles = [c for (s, c) in livraisons if s == n]
        fenetre = max(cycles) - min(cycles) + 1 if len(cycles) > 1 else 1
        debits[n] = (len(cycles), fenetre, len(cycles) / fenetre)
    return debits


@cocotb.test()
async def test_random_traffic_zero_loss(dut):
    """Trafic aleatoire depuis les 8 noeuds: chaque message accepte est livre
    exactement une fois au bon noeud (zero perte, zero doublon)."""
    rng = random.Random(42)
    await setup(dut)

    to_send = [[rng.choice(MSG_VALUES) for _ in range(10)] for _ in range(NB)]
    recu, _, _ = await run_traffic(dut, to_send, max_cycles=2000, rate=0.5, rng=rng)

    for i in range(NB):
        attendu = Counter(to_send[i])
        obtenu = recu[DEST_IDX[i]]
        assert obtenu == attendu, (
            f"noeud {i} -> noeud {DEST_IDX[i]}: envoye {dict(attendu)}, "
            f"recu {dict(obtenu)} (perte ou doublon)"
        )
    dut._log.info("zero perte: 80 messages envoyes par 8 noeuds, tous livres une fois")


@cocotb.test()
async def test_saturation_fairness(dut):
    """Le noeud 0 emet a plein debit; le noeud 1 (en aval) doit quand meme
    pouvoir injecter grace a la reservation de slot, en temps borne."""
    rng = random.Random(7)
    await setup(dut)

    # noeud 0: 60 messages back-to-back; noeud 1: 5 messages; les autres silencieux
    to_send = [[] for _ in range(NB)]
    to_send[0] = [rng.choice(MSG_VALUES) for _ in range(60)]
    to_send[1] = [rng.choice(MSG_VALUES) for _ in range(5)]
    recu, latences, livraisons = await run_traffic(dut, to_send, max_cycles=3000, rate=1.0, rng=rng)

    assert recu[DEST_IDX[1]] == Counter(to_send[1]), (
        f"messages du noeud affame perdus: envoye {Counter(to_send[1])}, "
        f"recu {dict(recu[DEST_IDX[1]])}"
    )
    assert recu[DEST_IDX[0]] == Counter(to_send[0]), "messages du noeud sature perdus"

    # borne: seuil de famine + marquage/retour du slot (<= 2 tours) + marge
    lat1 = [c for (s, c) in latences if s == 1]
    bound = STARVE_THRESH + 3 * NB + 8
    assert max(lat1) <= bound, (
        f"latence du noeud affame {max(lat1)} cycles > borne {bound}"
    )
    dut._log.info(
        "equite: latences noeud sature max=%d, noeud affame max=%d (borne %d)",
        max(c for (s, c) in latences if s == 0), max(lat1), bound,
    )

    # debit par noeud sur sa fenetre active (messages livres / cycle)
    debits = debit_par_noeud(livraisons, [0, 1])
    n0, f0, d0 = debits[0]
    n1, f1, d1 = debits[1]
    dut._log.info(
        "debit: noeud 0 sature %d msgs / %d cycles = %.3f msg/cycle (part de bande %.0f%%); "
        "noeud 1 affame %d msgs / %d cycles = %.3f msg/cycle",
        n0, f0, d0, 100 * d0, n1, f1, d1,
    )
    # le noeud sature ne peut pas monopoliser l'anneau: les slots reserves par le
    # noeud affame lui echappent, son debit doit rester < 1 msg/cycle
    assert d0 < 1.0, f"le noeud sature monopolise l'anneau ({d0:.3f} msg/cycle)"
    # le noeud affame obtient un debit minimal garanti par la reservation:
    # au pire 1 message tous les `bound` cycles
    assert d1 >= 1.0 / bound, (
        f"debit du noeud affame {d1:.4f} msg/cycle < garantie 1/{bound}"
    )
