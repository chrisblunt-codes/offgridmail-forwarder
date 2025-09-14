# Offgrid Forwarder - Architecture

## Components (Listener mode)

```mermaid
flowchart LR
  subgraph "Client host"
    C[Client TCP]
  end

  subgraph "Forwarder — listener"
    L[Listener]
    S[Session]
    UI[Upstream]
    %% interface marker for docs
    UT[UpstreamSelector TCP]
    US[SerialUpstream Serial]
  end

  subgraph "Network / Devices"
    P[(Primary TCP)]
    B[(Backup TCP)]
    D[(Serial Device)]
  end

  C --> L --> S --> UI
  UI --> UT
  UI --> US
  UT -->|try| P
  UT -->|fallback| B
  US --> D
```
- Upstream is a small interface; at runtime we pick TCP failover (UpstreamSelector) or Serial (SerialUpstream) based on UPSTREAM_MODE.

## Components (Pump mode)

```mermaid
flowchart LR
  D[(Serial Device)]

  subgraph Forwarder Pump
    Pump[SerialTcpPump]
    UT[[UpstreamSelector TCP]]
  end

  P[(Primary TCP)]
  B[(Backup TCP)]

  D <--> Pump
  Pump --> UT
  UT -->|try| P
  UT -->|fallback| B
```
- Pump runs without a TCP listener. It opens the local serial device and connects to a remote TCP upstream (with primary→backup failover), then proxies bytes in both directions.

## Sequence — Listener mode (generic Upstream)

```mermaid
sequenceDiagram
  participant C as Client
  participant L as Listener
  participant S as Session
  participant U as Upstream
  participant P as Primary (TCP)
  participant B as Backup (TCP)

  C->>L: TCP connect
  L->>S: spawn Session
  S->>U: connect()

  alt upstream = tcp
    U->>P: TCP connect (timeout T)
    alt primary ok
      U-->>S: socket(P)
    else primary fails
      U->>B: TCP connect
      U-->>S: socket(B)
    end
  else upstream = serial
    U-->>S: IO(serial) opened
  end

  S-->>U: stream client → upstream
  U-->>S: stream upstream → client

  note over S: On EOF/error in either direction, both sides close
```

## Sequence — Pump mode (Serial ↔ TCP)

```mermaid
sequenceDiagram
  participant Pump as SerialTcpPump
  participant D as Serial Device
  participant U as UpstreamSelector
  participant P as Primary (TCP)
  participant B as Backup (TCP)

  Pump->>D: open(serial, baud)
  Pump->>U: connect()

  U->>P: TCP connect (timeout T)
  alt primary ok
    U-->>Pump: socket(P)
  else primary fails
    U->>B: TCP connect
    U-->>Pump: socket(B)
  end

  Pump-->>D: tcp→serial bytes
  D-->>Pump: serial→tcp bytes

  note over Pump: stop() closes serial+tcp IOs → both copy fibers end
```

## Happy Path (Listener mode)

- Listener accepts client → spawns Session
- Session asks Upstream for a connection
- If TCP: UpstreamSelector tries primary, then backup
- If Serial: SerialUpstream opens the device (platform-specific init)
- Session proxies bytes both ways (two fibers)
- On EOF/error either side, both sides close

## Happy Path (Pump mode)

- Pump opens local serial device
- Pump connects to remote TCP upstream (primary → backup)
- Proxies bytes both ways until EOF/error
- stop() closes serial + tcp IOs, which breaks the copy fibers


## Config switches (quick reference)

- ROLE: `listener` (TCP listen) or `pump` (no listener; serial↔TCP)
- UPSTREAM_MODE: `tcp` or `serial` (listener mode only)
- SERIAL_DEV, SERIAL_BAUD: serial device path + baud (used by SerialUpstream and Pump)

_(Signal handling: in listener mode we stop accept and drain/force-close sessions; in pump mode we call pump.stop, which closes both IOs immediately.)_


## Future: Serial Multiplexing

Current implementation:  
- One serial link ↔ one TCP port (e.g. COM3 <-> 127.0.0.1:25).  
- For multiple services (SMTP + POP3), multiple cables or forwarders are needed.  

Planned enhancement:  
- Add a lightweight framing protocol on top of serial to multiplex multiple streams over one cable.  
- Each frame will include:
  - **Port ID** (e.g., 25, 110)
  - **Length** (number of payload bytes)
  - **Payload** (TCP data)


Example (little-endian, draft):  
```
+--------+--------+--------------------+
| PortID  | Length   | Payload (bytes) |
| 2B | 2B | variable |                 |
+--------+--------+--------------------+
```

### Notes:  

- First version can support fixed ports (25, 110, 143).  
- Later versions may support dynamic sessions with small channel IDs.  
- Must handle framing errors and resync (look for start marker or length sanity).  
- Throughput is shared, so add fair queueing if needed.
- OGL project maybe able to be plugged in here as that already has its own binary protocol.

Benefit:  
- A single serial cable can carry multiple TCP services, reducing hardware needs.
