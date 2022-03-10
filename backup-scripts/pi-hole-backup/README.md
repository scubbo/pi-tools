Uses basic Unix tools (ssh/scp/find) to make a snapshot of a Pi-hole
(on a static IP - TODO to make that parameterizable), copy it to a given
mounted directory, then cleanup both the remote pi-hole and all-but-a-few
of the local backups.
