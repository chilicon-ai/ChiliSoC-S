# Valid/Accept Handshake

The user-side interface of BaseChiliSV bus modules (e.g. `basechili_ahb_manager`,
`basechili_ahb_subordinate`). One transaction uses two handshake channels:

| Channel | Direction | Signals | Purpose |
|---------|-----------|---------|---------|
| `req` | initiator → responder | `req_valid`, `req_accept`, `req_*` payload | Request: address, direction, write data |
| `ack` | responder → initiator | `ack_valid`, `ack_accept`, `ack_*` payload | Response: read data, error |

## Rules

1. **Transfer:** a channel transfers on the rising clock edge where both
   `*_valid` and `*_accept` are high.
2. **Hold:** once `*_valid` is high, it stays high and its payload stays
   stable until the transfer happens.
3. **No waiting for accept:** the sender must not wait for `*_accept` before
   asserting `*_valid`. The receiver may wait for `*_valid` before asserting
   `*_accept`.
4. **No combinational loops:** `*_valid` must not depend combinationally on
   `*_accept`.
5. **Ordering:** the `ack` for a request transfers in the same cycle as that
   request's `req` transfer or later, never before. One request is
   outstanding at a time.

## Timing

Separate request and response cycles:

```
            ___     ___     ___     ___     ___     ___     ___
clk     ___|   |___|   |___|   |___|   |___|   |___|   |___|   |
                ___________________
req_valid  ____|                   |___________________________
                        ___________
req_accept ____________|           |___________________________
               <== payload stable =>     ^ req transfer (both high)
                                        ________________
ack_valid  ____________________________|                |______
                                                ________
ack_accept ____________________________________|        |______
                                        <= stable =>    ^ ack transfer
```

Request and response in the same cycle (responder answers immediately):

```
            ___     ___     ___     ___
clk     ___|   |___|   |___|   |___|   |
                _______
req_valid  ____|       |_______________
                _______
req_accept ____|       |_______________
                _______
ack_valid  ____|       |_______________
                _______
ack_accept ____|       |_______________
                       ^ req and ack transfer together
```

## Who Drives What

| Module | `req` channel | `ack` channel |
|--------|---------------|---------------|
| `basechili_ahb_manager` | user drives `req_valid`; manager drives `req_accept` | manager drives `ack_valid`; user drives `ack_accept` |
| `basechili_ahb_subordinate` | subordinate drives `req_valid`; user drives `req_accept` | user drives `ack_valid`; subordinate drives `ack_accept` |

Signal names are the same on both modules with directions flipped, so the
manager's user side and the subordinate's user side follow the same protocol
(a bridge needs only matching data widths).

## Module Notes

- In BaseChiliSV modules, `*_accept` and `*_valid` outputs are decoded from
  registered state only; they have no combinational path from the other side.
  Exception: `basechili_stream_reg` (one register) passes `out_accept` to
  `in_accept`; `basechili_skid_buffer` cuts both paths.
- `basechili_ahb_manager`: `req_wdata` / `ack_rdata` may be wider than the AHB data bus
  (`USER_DATA_W`); the request is sent as one burst. The response always
  comes at least one cycle after the request.
- `basechili_ahb_subordinate`: one request per AHB beat. `ack_accept` is high together
  with `req_valid`, so a user that responds in the request cycle gets a
  one wait state AHB transfer. `req_wdata` is taken directly from `HWDATA`
  and is stable while `req_valid` is high.
