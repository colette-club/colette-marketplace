# Digests

Members receive a weekly digest of new activities near them. `App.Digests.schedule/1` enqueues it as an Oban job (`App.Workers.SendDigest`, queue `mailers`).
