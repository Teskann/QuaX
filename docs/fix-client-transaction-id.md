# Fixing an `x-client-transaction-id` error

Symptom: requests fail before reaching the API, e.g. `Couldn't find the sign module`.

1. **Record what X serves now**

   ```bash
   fvm dart run tool/record/transaction_id.dart
   ```

2. **Run the tests**: they should fail and say what is wrong.

   ```bash
   fvm flutter test test/client/x_client_transaction_id/
   ```

3. **Fix the code** from the new files in `test/fixtures/XClientTransactionId/`
   (`sources.json` lists them): `ClientTransaction._findSignFileUrl` and
   `constants.dart`, or the algorithm itself if the ids differ.

4. **Run the tests again** until they pass.

More details: `tool/record/README.md`.
