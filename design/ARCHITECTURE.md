```mermaid
flowchart LR
  subgraph Client Host
    C[Client TCP]
  end

  subgraph Forwarder
    L[Listener]
    S[Session]
    U[UpstreamSelector]
  end

  subgraph Upstream
    P[(Primary TCP)]
    B[(Backup TCP)]
  end

  C --> L --> S --> U
  U -->|try| P
  U -->|fallback| B
  S <--> P
```

```mermaid
sequenceDiagram
  participant C as Client
  participant L as Listener
  participant S as Session
  participant U as UpstreamSelector
  participant P as Primary
  participant B as Backup

  C->>L: TCP connect
  L->>S: spawn Session
  S->>U: connect()
  U->>P: TCP connect (timeout T)
  alt primary ok
    U-->>S: socket(P)
  else primary fails
    U->>B: TCP connect
    U-->>S: socket(B)
  end

  S-->>P: stream client → upstream
  P-->>S: stream upstream → client
  note over S: close both sides when either ends
```

##  Happy Path

- Listener accepts client → spawns Session
- Session asks UpstreamSelector for connection
- UpstreamSelector tries primary, then backup
- Session proxies bytes both ways (two fibers)
- On EOF/error in either direction, both sockets close