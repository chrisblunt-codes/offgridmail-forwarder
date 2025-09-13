# Offgrid Mail (OGM) Forwarder

OffgridMail Forwarder (OGM Forwarder) — a lightweight TCP/Serial forwarder with failover. 
Part of the OffgridMail suite.

## Features

- Primary → backup failover
- Bidirectional streaming (two fibers)
- Simple CLI + ENV configuration

## Quickstart

```bash
# in one terminal, fake an upstream
nc -l -p 2526

# run the forwarder
PRIMARY=127.0.0.1:2526 BACKUP=127.0.0.1:2527 \
LISTEN_PORT=2525 crystal run src/ogm_forwarder.cr

# in another terminal, connect as a client
nc 127.0.0.1 2525
```

## Configuration

```
.----------------------------------------------------------------------------------------------.
| Setting          | ENV               | CLI                    | Default                      |
| ---------------- | ----------------- | ---------------------- | ---------------------------- |
| Listen host      | `LISTEN_HOST`     | `-l`, `--listen HOST`  | `127.0.0.1`                  |
| Listen port      | `LISTEN_PORT`     | `-p`, `--port PORT`    | `2525`                       |
| Primary upstream | `PRIMARY`         | `--primary HOST:PORT`  | `mailserver1.example.com:25` |
| Backup upstream  | `BACKUP`          | `--backup HOST:PORT`   | `mailserver2.example.com:25` |
| Connect timeout  | `CONNECT_TIMEOUT` | —                      | `5` seconds                  |
| RW timeout       | `RW_TIMEOUT`      | —                      | `120` seconds                |
| Log level        | `LOG_LEVEL`       | `-q`, `-v`, `--silent` | `Info`                       |
"----------------------------------------------------------------------------------------------'
```

## Documentation

- Architecture notes: design/ARCHITECTURE.md
- Generate API docs: crystal docs → outputs to docs/ (auto-generated; don’t commit)

## Development

```
shards install
crystal spec        # if/when specs exist
crystal run src/ogm_forwarder.cr -- --help
# build a release binary
crystal build --release src/ogm_forwarder.cr -o bin/ogm-forwarder
```

## Contributing

1. Fork it (https://github.com/chrisblunt-codes/offgridmail-forwarder/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

Chris Blunt - creator and maintainer

## License

Copyright 2025 Chris Blunt  
Licensed under the Apache License, Version 2.0  
SPDX-License-Identifier: Apache-2.0

