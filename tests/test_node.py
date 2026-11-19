"""Directed node-level tests (adr_cur=5, adr_dest=8, STARVE_THRESH=16 by default)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

EMPTY = 0x0F0          # resv=0, addr=F, msg=0
RESV_EMPTY = 0x1F0     # slot vide marque reserve
ADR_CUR = 0x5
ADR_DEST = 0x8
STARVE_THRESH = 16


async def setup(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.tr_in.value = EMPTY
    dut.test_in.value = 0
    dut.env_mess.value = 0
    dut.mess_in.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)


async def tick(dut):
    """Un front montant, puis lecture des sorties (stables) au front descendant,
    ou l'ecriture des entrees pour le cycle suivant est aussi permise."""
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)


@cocotb.test()
async def test_forward(dut):
    """Une trame en transit (pas pour ce noeud) est retransmise telle quelle."""
    await setup(dut)
    dut.tr_in.value = 0x0A1
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x0A1, "trame en transit non retransmise"


@cocotb.test()
async def test_absorb(dut):
    """Une trame adressee a ce noeud est delivree et le slot est libere."""
    await setup(dut)
    dut.tr_in.value = 0x05A  # addr=5 (nous), msg=A
    await tick(dut)
    assert dut.mess_out.value.to_unsigned() == 0xA, "message non delivre"
    assert dut.tr_out.value.to_unsigned() == EMPTY, "le slot doit etre libere"


@cocotb.test()
async def test_inject_empty_slot(dut):
    """ENV_MESS avec un slot vide: injection directe."""
    await setup(dut)
    dut.env_mess.value = 1
    dut.mess_in.value = 0x3
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x083, "injection directe attendue (x83)"


@cocotb.test()
async def test_inject_during_transit(dut):
    """Collision: le message est bufferise (BUSY), puis emis sur le prochain slot libre."""
    await setup(dut)
    dut.tr_in.value = 0x0A1
    dut.env_mess.value = 1
    dut.mess_in.value = 0x7
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x0A1, "transit prioritaire"
    assert int(dut.busy.value) == 1, "BUSY attendu apres bufferisation"

    dut.env_mess.value = 0
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x0A1, "transit toujours prioritaire"

    dut.tr_in.value = EMPTY
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x087, "le buffer doit sortir sur le slot libre"
    assert int(dut.busy.value) == 0, "BUSY doit retomber"


@cocotb.test()
async def test_buffer_full_refusal(dut):
    """Un ENV_MESS pendant BUSY=1 est refuse: pas de double acceptation."""
    await setup(dut)
    # remplir le buffer
    dut.tr_in.value = 0x0A1
    dut.env_mess.value = 1
    dut.mess_in.value = 0x7
    await tick(dut)
    assert int(dut.busy.value) == 1

    # presenter un second message pendant BUSY: doit etre ignore
    dut.mess_in.value = 0x9
    await tick(dut)
    assert int(dut.busy.value) == 1

    # slot libre: le buffer (x7) sort; le x9 presente pendant BUSY ne doit PAS avoir ete pris
    dut.tr_in.value = EMPTY
    dut.env_mess.value = 0
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x087, "seul le premier message doit sortir"
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == EMPTY, "aucun doublon ne doit etre emis"


@cocotb.test()
async def test_loopback(dut):
    """TEST_IN: la trame de test revient -> TEST_OK."""
    await setup(dut)
    dut.test_in.value = 1
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x05C, "trame de test attendue (5C)"
    dut.tr_in.value = 0x05C
    await tick(dut)
    assert int(dut.test_ok.value) == 1, "TEST_OK attendu"
    dut.test_in.value = 0
    dut.tr_in.value = EMPTY
    await tick(dut)
    assert int(dut.test_ok.value) == 0


@cocotb.test()
async def test_reservation(dut):
    """Famine -> marquage d'une trame -> consommation exclusive du slot reserve."""
    await setup(dut)
    # charger le buffer pendant un transit continu
    dut.tr_in.value = 0x0A1
    dut.env_mess.value = 1
    dut.mess_in.value = 0x9
    await tick(dut)
    dut.env_mess.value = 0
    assert int(dut.busy.value) == 1

    # saturer jusqu'au marquage (STARVE_THRESH cycles de comptage + 1 de marquage)
    marked = False
    for _ in range(STARVE_THRESH + 2):
        await tick(dut)
        if dut.tr_out.value.to_unsigned() == 0x1A1:
            marked = True
            break
    assert marked, "la trame qui passe doit etre marquee reservee"

    # un slot libre NON reserve pendant la reservation: laisse aux autres noeuds
    dut.tr_in.value = EMPTY
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == EMPTY, \
        "pendant la reservation, les slots libres ordinaires sont laisses aux autres"
    assert int(dut.busy.value) == 1

    # le slot reserve revient: consommation, bit resv efface
    dut.tr_in.value = RESV_EMPTY
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x089, "le buffer doit sortir sur le slot reserve"
    assert int(dut.busy.value) == 0

    # un slot reserve pour un autre noeud circule intact, sans injection directe;
    # le message presente est bufferise (contrat BUSY='0' => accepte)
    dut.env_mess.value = 1
    dut.mess_in.value = 0x3
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == RESV_EMPTY, \
        "slot reserve pour un autre noeud: aucune injection permise"
    assert int(dut.busy.value) == 1, "le message presente doit etre bufferise"
    dut.env_mess.value = 0
    dut.tr_in.value = EMPTY
    await tick(dut)
    assert dut.tr_out.value.to_unsigned() == 0x083, \
        "le message bufferise sort sur le prochain slot libre ordinaire"
